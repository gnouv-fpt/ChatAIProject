using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Infrastructure.Implementations;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace ChatAIWeb.Tests;

public sealed class SplitDatabaseTests
{
    private static readonly System.Text.Json.JsonSerializerOptions JsonOptions = new(System.Text.Json.JsonSerializerDefaults.Web)
    {
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter() }
    };
    private static readonly JwtSettings Jwt = new()
    {
        SecretKey = "only-for-isolated-tests-32-bytes-minimum-value",
        Issuer = "C2Tests", Audience = "C2Tests.Clients"
    };

    [Fact]
    public void SqlMigrationsHaveDisjointTablesAndNoRefreshTokenOrCrossDatabaseForeignKey()
    {
        using var user = new UserDbContextFactory().CreateDbContext([]);
        using var content = new ContentDbContextFactory().CreateDbContext([]);
        Assert.Equal(new[] { "ExamAttempts", "UserChatMessages", "UserChatSessions", "Users" },
            user.Model.GetEntityTypes().Select(e => e.GetTableName()).Order().ToArray());
        Assert.Equal(new[] { "ExamTemplateItems", "ExamTemplates", "LegalDocumentChunks", "LegalDocuments", "TrafficQuestionCategories", "TrafficQuestions" },
            content.Model.GetEntityTypes().Select(e => e.GetTableName()).Order().ToArray());
        var userSql = user.Database.GenerateCreateScript();
        Assert.DoesNotContain("RefreshTokens", userSql);
        Assert.DoesNotContain("LegalDocument", userSql);
        Assert.Contains("CitationsJson", userSql);
        Assert.DoesNotContain("UserChat", content.Database.GenerateCreateScript());
        Assert.Single(user.Database.GetMigrations());
        Assert.Equal(2, content.Database.GetMigrations().Count());
    }

    [Fact]
    public async Task CitationSnapshotsPersistWithoutContentTablesOrForeignKeys()
    {
        await using var connection = OpenDatabase();
        await using var db = new UserDbContext(new DbContextOptionsBuilder<UserDbContext>().UseSqlite(connection).Options);
        await db.Database.EnsureCreatedAsync();
        var user = NewUser();
        var message = new ChatMessage
        {
            Id = Guid.NewGuid(), Session = new ChatSession { Id = Guid.NewGuid(), User = user, Title = "test" },
            Content = "test", Citations = [new Citation
            {
                Id = Guid.NewGuid(), DocumentChunkId = Guid.NewGuid(), DocumentTitle = "Snapshot law"
            }]
        };
        db.ChatMessages.Add(message);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        var saved = await db.ChatMessages.SingleAsync();
        Assert.Equal("Snapshot law", saved.Citations.Single().DocumentTitle);
        saved.Citations.Single().DocumentTitle = "Updated snapshot";
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        Assert.Equal("Updated snapshot", (await db.ChatMessages.SingleAsync()).Citations.Single().DocumentTitle);
    }

    [Fact]
    public async Task SubmittedSnapshotSurvivesWithoutRedisOrContentDbAndCannotBeInsertedTwice()
    {
        await using var connection = OpenDatabase();
        await using var db = new UserDbContext(new DbContextOptionsBuilder<UserDbContext>().UseSqlite(connection).Options);
        await db.Database.EnsureCreatedAsync();
        var user = NewUser();
        var attempt = new ExamAttempt
        {
            Id = Guid.NewGuid(), User = user, ExamCode = "CUSTOM-EXPIRED", ExamVersion = 1,
            SubmissionHash = new string('a', 64), ExamSnapshotJson = "{\"question\":\"old version\"}",
            UserAnswersJson = "[{\"key\":\"A\"}]", SubmittedAt = DateTime.UtcNow
        };
        db.ExamAttempts.Add(attempt);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        var repository = new DataAccess.Repositories.Implementations.ExamAttemptRepository(db);
        Assert.Null(await repository.GetOwnedAsync(attempt.Id, Guid.NewGuid(), default));
        Assert.Equal(attempt.ExamSnapshotJson, (await repository.GetOwnedAsync(attempt.Id, user.Id, default))!.ExamSnapshotJson);
        db.ExamAttempts.Add(new ExamAttempt
        {
            Id = attempt.Id, UserId = user.Id, ExamCode = attempt.ExamCode, ExamVersion = 1,
            SubmissionHash = attempt.SubmissionHash
        });
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task TemplateRejectsDuplicateQuestionAndUnpublishedQuestionsDoNotLeakToSelection()
    {
        await using var connection = OpenDatabase();
        await using var db = new ContentDbContext(new DbContextOptionsBuilder<ContentDbContext>().UseSqlite(connection).Options);
        await db.Database.EnsureCreatedAsync();
        var category = new TrafficQuestionCategory { Id = Guid.NewGuid(), Type = "SIGN", SubCategoryCode = "5.1", Name = "Signs" };
        var question = new TrafficQuestion
        {
            Id = Guid.NewGuid(), Category = category, BankCode = "BANK", BankVersion = 1,
            QuestionCode = "Q001", CorrectAnswerKey = "A"
        };
        var template = new ExamTemplate
        {
            Id = Guid.NewGuid(), ExamCode = "EXAM", Version = 1, Title = "Test", DurationMinutes = 10,
            IsPublished = true, Items = [new ExamTemplateItem { Id = Guid.NewGuid(), Question = question, OrderIndex = 1 }]
        };
        db.ExamTemplates.Add(template);
        await db.SaveChangesAsync();
        var repository = new DataAccess.Repositories.Implementations.QuestionCatalogRepository(db);
        Assert.Empty(await repository.GetPublishedAsync("BANK", 1, null, default));
        Assert.Null(await repository.GetPublishedTemplateAsync("EXAM", 1, default));
        question.IsPublished = true;
        await db.SaveChangesAsync();
        Assert.Single(await repository.GetPublishedAsync("BANK", 1, null, default));
        db.ExamTemplateItems.Add(new ExamTemplateItem { Id = Guid.NewGuid(), ExamTemplateId = template.Id, QuestionId = question.Id, OrderIndex = 2 });
        await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task StatelessRefreshRejectsAccessServiceExpiredAndTamperedTokens()
    {
        var tokens = new JwtTokenService(Jwt);
        var user = NewUser();
        var refresh = tokens.CreateRefreshToken(user);
        Assert.Equal(user.Id, (await tokens.ValidateRefreshTokenAsync(refresh.Token))!.UserId);
        Assert.Null(await tokens.ValidateRefreshTokenAsync(tokens.CreateAccessToken(user).Token));
        Assert.Null(await tokens.ValidateRefreshTokenAsync(tokens.CreateContentServiceToken()));
        Assert.Null(await tokens.ValidateRefreshTokenAsync(refresh.Token + "tamper"));
        Assert.Null(await tokens.ValidateRefreshTokenAsync("not-a-token"));
        var expired = new JwtTokenService(new JwtSettings
        {
            SecretKey = Jwt.SecretKey, Issuer = Jwt.Issuer, Audience = Jwt.Audience, RefreshTokenDays = -1
        });
        Assert.Null(await tokens.ValidateRefreshTokenAsync(expired.CreateRefreshToken(user).Token));
    }

    [Fact]
    public async Task TwoHostsExposeOnlyTheirOwnControllersAndInternalReadRequiresServiceToken()
    {
        using var content = new ModuleFactory("Content");
        using var user = new ModuleFactory("User");
        using var contentHttp = content.CreateClient();
        using var userHttp = user.CreateClient();
        Assert.Equal(HttpStatusCode.NotFound, (await contentHttp.GetAsync("/api/auth/profile")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await userHttp.GetAsync("/api/documents")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await userHttp.GetAsync("/api/auth/profile")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await contentHttp.GetAsync("/api/documents")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await contentHttp.PostAsJsonAsync("/internal/content/chunks", Array.Empty<Guid>())).StatusCode);
        var tokens = new JwtTokenService(Jwt);
        contentHttp.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateAccessToken(NewUser()).Token);
        Assert.Equal(HttpStatusCode.Unauthorized, (await contentHttp.PostAsJsonAsync("/internal/content/chunks", Array.Empty<Guid>())).StatusCode);
        contentHttp.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateContentServiceToken());
        Assert.Equal(HttpStatusCode.OK, (await contentHttp.PostAsJsonAsync("/internal/content/chunks", Array.Empty<Guid>())).StatusCode);
        contentHttp.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateRefreshToken(NewUser()).Token);
        Assert.Equal(HttpStatusCode.Unauthorized, (await contentHttp.PostAsJsonAsync("/internal/content/chunks", Array.Empty<Guid>())).StatusCode);
        userHttp.DefaultRequestHeaders.Authorization = contentHttp.DefaultRequestHeaders.Authorization;
        Assert.Equal(HttpStatusCode.Unauthorized, (await userHttp.GetAsync("/api/auth/profile")).StatusCode);
    }

    [Fact]
    public async Task ContentClientReadsVerifiedEvidenceAcrossHttpWithoutUserDbContentTables()
    {
        using var content = new ModuleFactory("Content");
        using var http = content.CreateClient();
        var id = Guid.NewGuid();
        using (var scope = content.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ContentDbContext>();
            db.DocumentChunks.Add(new DocumentChunk
            {
                Id = id, Content = "Verified evidence", IsVerified = true, Article = "1",
                Document = new LegalDocument
                {
                    Id = Guid.NewGuid(), DocumentNumber = "TEST", Title = "Test law", IsActive = true,
                    VerificationStatus = VerificationStatus.Verified, SourceUrl = "https://thuvienphapluat.vn/test", Version = 2
                }
            });
            await db.SaveChangesAsync();
        }
        var client = new ContentCatalogClient(http, new JwtTokenService(Jwt));
        var chunks = await client.GetChunksAsync([id], default);
        Assert.Equal(id, chunks.Single().Id);
        Assert.Equal(2, chunks.Single().Document.Version);
        Assert.Empty(await client.GetChunksAsync([Guid.NewGuid()], default));
    }

    [Fact]
    public async Task RegisterRefreshAndLogoutUseOnlyUserDbAndDoNotExtendRefreshExpiry()
    {
        using var user = new ModuleFactory("User");
        using var http = user.CreateClient();
        var response = await http.PostAsJsonAsync("/api/auth/register", new { Username = "tester", Email = "tester@test.local", Password = "Strong@123456" });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var auth = await response.Content.ReadFromJsonAsync<BusinessLogic.DTOs.Responses.AuthResponseDto>(JsonOptions);
        var refresh = await http.PostAsJsonAsync("/api/auth/refresh-token", new { auth!.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, refresh.StatusCode);
        var refreshed = await refresh.Content.ReadFromJsonAsync<BusinessLogic.DTOs.Responses.AuthResponseDto>(JsonOptions);
        Assert.Equal(auth.RefreshToken, refreshed!.RefreshToken);
        Assert.True(Math.Abs((auth.RefreshTokenExpiresAt - refreshed.RefreshTokenExpiresAt).TotalSeconds) < 1);
        Assert.Equal(HttpStatusCode.NoContent, (await http.PostAsJsonAsync("/api/auth/logout", new { auth.RefreshToken })).StatusCode);
        // Client-held token is intentionally not revoked by a database marker.
        Assert.Equal(HttpStatusCode.OK, (await http.PostAsJsonAsync("/api/auth/refresh-token", new { auth.RefreshToken })).StatusCode);
    }

    [Fact]
    public async Task AdminCanBeSeededAfterExternalMigrationWithoutEnablingStartupMigrations()
    {
        using var user = new ModuleFactory("User", seedAdmin: true);
        using var http = user.CreateClient();
        var response = await http.PostAsJsonAsync("/api/auth/login", new { Email = "admin-fixture@test.local", Password = "TestOnly@123456" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var auth = await response.Content.ReadFromJsonAsync<BusinessLogic.DTOs.Responses.AuthResponseDto>(JsonOptions);
        Assert.Equal(UserRole.Admin, auth!.User.Role);
    }

    private static User NewUser() => new() { Id = Guid.NewGuid(), Username = Guid.NewGuid().ToString("N"), Email = Guid.NewGuid() + "@test.local", PasswordHash = "test" };
    private static SqliteConnection OpenDatabase()
    {
        var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();
        connection.CreateFunction<string, int>("ISJSON", value =>
        {
            try { System.Text.Json.JsonDocument.Parse(value).Dispose(); return 1; } catch { return 0; }
        });
        return connection;
    }

    private sealed class ModuleFactory(string module, bool seedAdmin = false) : WebApplicationFactory<Program>
    {
        private readonly SqliteConnection connection = OpenDatabase();
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseSetting("Service:Module", module);
            builder.UseSetting("Jwt:SecretKey", Jwt.SecretKey);
            builder.UseSetting("Jwt:Issuer", Jwt.Issuer);
            builder.UseSetting("Jwt:Audience", Jwt.Audience);
            builder.UseSetting("Database:MigrateOnStartup", "false");
            builder.UseSetting("Auth:SeedAdminOnStartup", seedAdmin.ToString());
            builder.UseSetting("Auth:SeedAdmin:Email", "admin-fixture@test.local");
            builder.UseSetting("Auth:SeedAdmin:Password", "TestOnly@123456");
            builder.UseSetting("Jobs:EnableLegacyMidnight", "false");
            builder.UseSetting("Chat:AttachmentRoot", Path.Combine(Path.GetTempPath(), "c2-tests", Guid.NewGuid().ToString("N"), "attachments"));
            builder.UseSetting("Logging:LogLevel:Default", "Error");
            builder.UseSetting("Logging:FilePath", Path.Combine(Path.GetTempPath(), "c2-tests", Guid.NewGuid() + ".jsonl"));
            builder.ConfigureServices(services =>
            {
                if (module == "User")
                {
                    services.RemoveAll<DbContextOptions<UserDbContext>>();
                    services.AddDbContext<UserDbContext>(options => options.UseSqlite(connection));
                    using var db = new UserDbContext(new DbContextOptionsBuilder<UserDbContext>().UseSqlite(connection).Options);
                    db.Database.EnsureCreated();
                }
                else
                {
                    services.RemoveAll<DbContextOptions<ContentDbContext>>();
                    services.AddDbContext<ContentDbContext>(options => options.UseSqlite(connection));
                    using var db = new ContentDbContext(new DbContextOptionsBuilder<ContentDbContext>().UseSqlite(connection).Options);
                    db.Database.EnsureCreated();
                }
            });
        }
        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);
            if (disposing) connection.Dispose();
        }
    }
}
