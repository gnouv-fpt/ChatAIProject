# AGENTS.md — ChatAIWeb Project Instructions

## Current scope — 2026-10-27 (supersedes the 2026-10-24 plan)

Read task.md and docs/IMPLEMENTATION-PLAN.md for the current assignments. Two independent SQL databases: User (accounts/chat/exam attempts) and Content/Exam (legal documents/chunks/question bank/templates/items); Qdrant is the vector database. Redis holds user-owned custom exams with TTL. Kafka carries notifications/events between the two application services; Kafka-driven quota settlement from the old plan is not a current requirement. HTML animations are hosted separately; questions store ExplanationAnimationUrl.

Vuong owns shared entities/schema/repository contracts, both DbContexts/configurations and migrations. Bao owns User business/query modules, Phuc owns Content/Exam business/query modules, Khanh owns Redis custom exams/scoring and Kafka notifications, Khoi owns AI/proto/Qdrant. Do not independently generate migrations or change shared schema: send field/query requirements to Vuong. Publish the initial schema contract early, then review integrated migrations at the end. Preserve existing commits/migrations for transition review.

This is target architecture, not proof that the checked-out source already implements it. Keep useful branch code and adapt it; do not reset/rewrite others' work.

## 1. Project Overview

PRN232 assignment: **Vietnam Traffic Law Advanced RAG System** — a microservices system that answers Vietnamese road-traffic law questions using only verified legal documents from thuvienphapluat.vn, with citations (Điều, Khoản, Điểm, document title, source URL).

Services (see `requirement.md` for the full spec):

- **REST API Service** — this .NET solution (`Presentation` project): ASP.NET Core 8 Web API, JWT, Swagger.
- **gRPC Inference & Verification Service** — moderation + RAG over Qdrant (separate service).
- **Application services** — User and Content/Exam APIs behind the Gateway, each owning its SQL database.
- **Message Broker** — Kafka for service-to-service notification events; topic/payload/consumer contracts are finalized at P0.
- **Redis** — custom exam snapshots/state/deadline/TTL and optional cache; not the canonical question bank.
- **Worker Service** — notification/retry and scheduled handlers according to service ownership; no mandatory Kafka quota-settlement pipeline.
- **Docker Compose** — Gateway, application/AI/Worker hosts, two SQL databases, Qdrant, Redis and Kafka; deployment mapping finalized at P0.

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
- Repositories share a scoped DbContext only within their owning database. SaveChangesAsync/transactions do not span the two databases. No cross-database EF navigation/FKs/joins; use API/event contracts and logical IDs/version snapshots.

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

Two independent SQL Server databases, EF Core code-first, separate contexts/connection strings/migration histories owned by Vuong:

- User: USERS, USER_CHAT_SESSIONS, USER_CHAT_MESSAGES, EXAM_ATTEMPTS.
- Content/Exam: LEGAL_DOCUMENTS, LEGAL_DOCUMENT_CHUNKS, TRAFFIC_QUESTION_CATEGORIES, TRAFFIC_QUESTIONS, EXAM_TEMPLATES, EXAM_TEMPLATE_ITEMS.
- Qdrant: vectors with document/chunk IDs and version metadata. Redis: user-owned custom exams with TTL.

The old single-database/seven-table limit is superseded. No RefreshTokens table in the target schema; no separate ViolationLogs/UsageReports just for logging/reporting. Citations use User message snapshots without FKs into Content DB. Attempts retain stable exam/version references and enough snapshot data to review submitted work after Redis expiry.

- Final physical names, ID types/mapping, JSON fields and constraints are published in Vuong's P0 schema contract. Do not mechanically replace GUIDs with integers from diagram labels.
- Enums remain strings; store timestamps in UTC and display Vietnam time.
- Vuong generates migrations with an explicit --context and separate output directory per database after contexts exist. Other contributors send model/query proposals; do not generate new migrations independently.
- Preserve existing migrations; inspect applied state and plan data transition before destructive changes. Do not start migration-on-startup against existing databases just to verify a build.
- Configuration holds separate connection strings; never hard-code credentials. Gateway routes to services, never directly to database connections.

---

## 6. Authentication

- `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/refresh-token`, `POST /api/auth/logout`, `GET /api/auth/profile`.
- Access token = JWT (HS256) with claims `sub` (UserId), `unique_name`, `email`, `role`, `token_quota` (names in `BusinessLogic/Infrastructure/AppClaimTypes.cs`).
- Target scope removes the RefreshTokens table and keeps tokens on the client. Bao/Vuong must define expiry, validation, whether refresh remains, logout and revocation semantics at P0 before changing endpoints. Client storage alone does not preserve the current database-backed single-use rotation/revocation guarantees. Existing refresh/logout routes describe legacy source until adapted.
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

The setup scripts/current DefaultConnection are legacy single-database bootstrap until adapted. The target needs reachable User and Content/Exam databases and separately configured connections. Vuong owns provisioning/migration changes; do not assume running the old script creates the new topology.

---

## 9. Verification

```bash
dotnet run --project Presentation --launch-profile http   # Swagger: http://localhost:5039/swagger
```

Check dependency direction, async usage, thin controllers and no business rules in repositories. After both contexts exist, check pending model changes separately with explicit --context and the correct startup host. Verify Gateway routes, database isolation, Redis ownership/TTL/submit recovery and Kafka notifications on the integrated runtime. Build/model checks do not apply migrations.

---

## 10. Git Safety

- Small, incremental changes; do not rewrite unrelated code.
- Do not move files between layers without checking dependency direction.
- The previous Razor Pages / course-document implementation is recoverable from commit `f178699` if any logic needs to be ported.
