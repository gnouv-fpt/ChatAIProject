# AGENTS.md — ChatAIWeb Project Instructions

## 1. Project Overview

PRN232 assignment: **Vietnam Traffic Law Advanced RAG System** — a microservices system that answers Vietnamese road-traffic law questions using only verified legal documents from thuvienphapluat.vn, with citations (Điều, Khoản, Điểm, document title, source URL).

Services (see `requirement.md` for the full spec):

- **REST API Service** — this .NET solution (`Presentation` project): ASP.NET Core 8 Web API, JWT, Swagger.
- **gRPC Inference & Verification Service** — moderation + RAG over Qdrant (separate service).
- **Message Broker** — Redis Pub/Sub / Kafka, topics `chat-completed-events`, `document-updated-events`.
- **Worker Service** — consumes `ChatCompletedEvent` (quota deduction, violation email) + midnight cron jobs.
- **Docker Compose** — sqlserver, qdrant, redis, grpc-inference-service, rest-api-service, worker-service.

The REST API solution must follow a strict **3-layer architecture**. There are no Razor Pages; the API is consumed by React/mobile/Postman clients.

---

## 2. Solution Structure

```text
ChatAIWeb.slnx
├── BusinessObject      Entities, Enums
├── DataAccess          ChatAIWebDbContext, Migrations, Repositories
├── BusinessLogic       DTOs, Exceptions, Infrastructure, Services
└── Presentation        Controllers, Middleware, Extensions, Program.cs, appsettings.json
```

```text
Presentation   = ASP.NET Core Web API (controllers, auth, Swagger, DI)
BusinessLogic  = business rules and orchestration
DataAccess     = EF Core, database access, repositories
BusinessObject = shared entities and enums
```

---

## 3. Architecture Rules

### 3.1. Presentation

Allowed: `[ApiController]` controllers under `Controllers/`, routing (`api/...`), `[Authorize]` attributes, middleware, DI registration in `Program.cs`, reading configuration.

Not allowed: EF Core queries, business rules, LLM/gRPC business logic inside controllers.

Controllers must be thin and only call `BusinessLogic` services:

```csharp
[ApiController]
[Route("api/chats")]
[Authorize]
public class ChatsController : ControllerBase
{
    private readonly IChatService _chatService;

    public ChatsController(IChatService chatService) => _chatService = chatService;

    [HttpGet("{sessionId:guid}")]
    public async Task<ActionResult<ChatSessionDetailDto>> Get(Guid sessionId, CancellationToken cancellationToken)
    {
        return await _chatService.GetSessionAsync(User.GetUserId(), sessionId, cancellationToken);
    }
}
```

- Get the current user with `User.GetUserId()` (`Presentation/Extensions/ClaimsPrincipalExtensions.cs`).
- Admin-only endpoints: `[Authorize(Roles = nameof(UserRole.Admin))]`.
- Request DTOs are validated with DataAnnotations; `[ApiController]` returns 400 automatically.

### 3.2. BusinessLogic

Business rules, orchestration, calling repositories and external clients (gRPC client, broker producer, crawler).

- Signal errors by throwing the exceptions in `BusinessLogic/Exceptions/AppException.cs` (`BadRequestException`, `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `ConflictException`). The global handler (`Presentation/Middleware/GlobalExceptionHandler.cs`) turns them into RFC 7807 ProblemDetails with the right status code. Do not return error flags or catch-and-swallow.
- Must not contain controller/HTTP concerns.

### 3.3. DataAccess

`ChatAIWebDbContext`, migrations, repositories. No business decisions.

- `IGenericRepository<T>` / `GenericRepository<T>` provides `GetByIdAsync`, `FindAsync`, `AnyAsync`, `AddAsync`, `Update`, `Remove`, `SaveChangesAsync`. It is registered as an open generic, so `IGenericRepository<ChatSession>` can be injected directly.
- Add a specific repository (`IXxxRepository : IGenericRepository<Xxx>`) only when you need custom queries (includes, paging, filtering).
- All repositories share the scoped DbContext: one `SaveChangesAsync` persists every pending change in the request.

### 3.4. BusinessObject

Entity classes and enums only. No dependencies on other layers.

---

## 4. Dependency Rules

```text
Presentation → BusinessLogic → DataAccess → BusinessObject
```

Forbidden: `BusinessObject → *`, `DataAccess → BusinessLogic/Presentation`, `BusinessLogic → Presentation`.

---

## 5. Database Rules

SQL Server database `ChatAIWebDb`, EF Core **code-first migrations** (in `DataAccess/Migrations`). The API applies pending migrations on startup (`Database:MigrateOnStartup`).

Tables: `Users`, `RefreshTokens`, `LegalDocuments`, `DocumentChunks`, `ChatSessions`, `ChatMessages`, `Citations`, `ViolationLogs`, `UsageReports`.

- Primary keys are `Guid`. Enums are stored as strings. All `DateTime` values are UTC (`DateTime.UtcNow`).
- After changing entities or `ChatAIWebDbContext`, add a migration:

```bash
dotnet ef migrations add <Name> --project DataAccess --startup-project Presentation --output-dir Migrations
```

- The connection string lives in `Presentation/appsettings.json` (`ConnectionStrings:DefaultConnection`); never hard-code it.

---

## 6. Authentication

- `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/refresh-token`, `POST /api/auth/logout`, `GET /api/auth/profile`.
- Access token = JWT (HS256) with claims `sub` (UserId), `unique_name`, `email`, `role`, `token_quota` (names in `BusinessLogic/Infrastructure/AppClaimTypes.cs`).
- Refresh tokens are random, stored as SHA-256 hashes, single-use (rotated on refresh), revoked on logout.
- Passwords are hashed with PBKDF2-HMACSHA256 (`PasswordHasher`).

---

## 7. Coding Style

- async/await everywhere; never `.Result`, `.Wait()` or `SaveChanges()`.
- Pass `CancellationToken` through controllers → services → repositories.
- Interfaces start with `I`; services end with `Service`; repositories end with `Repository`; async methods end with `Async`; DTOs end with `Dto`.
- Code identifiers in English; user-facing messages (validation, errors) in Vietnamese, e.g. `Không tìm thấy phiên chat.`
- Log technical details with `ILogger`; never return stack traces to clients.

---

## 8. Security Rules

Never commit secrets (JWT secret key, OpenAI/Gemini/Qdrant keys, DB passwords, SMTP credentials).

- Local development: `dotnet user-secrets` on the `Presentation` project.
- Docker / servers: environment variables (e.g. `Jwt__SecretKey`, `Auth__SeedAdmin__Password`).

Required local secrets — run once after cloning/pulling, instead of setting them by hand:

```bash
pwsh -File scripts/setup.ps1   # Windows
bash scripts/setup.sh          # macOS/Linux
```

This restores packages, generates a random `Jwt:SecretKey` (skipped if one already exists), seeds a default `Auth:SeedAdmin` (admin@chataiweb.local / Admin@123456), and builds the solution. To set secrets manually instead:

```bash
dotnet user-secrets set "Jwt:SecretKey" "<random string of at least 32 bytes>" --project Presentation
dotnet user-secrets set "Auth:SeedAdmin:Email" "admin@chataiweb.local" --project Presentation
dotnet user-secrets set "Auth:SeedAdmin:Password" "<password>" --project Presentation
```

Requires a reachable SQL Server (`ConnectionStrings:DefaultConnection` in `Presentation/appsettings.json`, default is `localhost` with Windows Authentication) — install SQL Server/LocalDB or point it at a container. The API creates/migrates `ChatAIWebDb` automatically on startup.

---

## 9. Verification

```bash
dotnet run --project Presentation --launch-profile http   # Swagger: http://localhost:5039/swagger
```

Check: dependency direction, async usage, thin controllers, no business rules in repositories, no pending model changes (`dotnet ef migrations has-pending-model-changes --project DataAccess --startup-project Presentation`).

---

## 10. Git Safety

- Small, incremental changes; do not rewrite unrelated code.
- Do not move files between layers without checking dependency direction.
- The previous Razor Pages / course-document implementation is recoverable from commit `f178699` if any logic needs to be ported.
