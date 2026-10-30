using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Exams;
using BusinessLogic.Infrastructure.Implementations;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessObject.Entities;
using BusinessObject.Enums;
using Confluent.Kafka;
using DataAccess;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using StackExchange.Redis;
using WorkerService;
using Xunit;

namespace C2.Integration.Tests;

public sealed class InfrastructureFactAttribute : FactAttribute
{
    public InfrastructureFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("C2_TEST_SQL") is null)
            Skip = "Set C2_TEST_SQL, C2_TEST_REDIS and C2_TEST_KAFKA for real infrastructure checks.";
    }
}

public sealed class ExamFlowTests
{
    [InfrastructureFact]
    public async Task PublishedSqlBankToRedisSubmissionUserSqlKafkaInboxAndReviewAfterRedisExpiry()
    {
        var suffix = Guid.NewGuid().ToString("N");
        var server = Environment.GetEnvironmentVariable("C2_TEST_SQL")!;
        var userConnection = server.TrimEnd(';') + ";Database=C2MergeUser_" + suffix;
        var contentConnection = server.TrimEnd(';') + ";Database=C2MergeContent_" + suffix;
        var jwt = new JwtSettings { SecretKey = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32)) };
        var settings = new Dictionary<string, string?>
        {
            ["ConnectionStrings:UserConnection"] = userConnection, ["ConnectionStrings:ContentConnection"] = contentConnection,
            ["ConnectionStrings:Redis"] = Environment.GetEnvironmentVariable("C2_TEST_REDIS") ?? "localhost:16379",
            ["Exams:Kafka:BootstrapServers"] = Environment.GetEnvironmentVariable("C2_TEST_KAFKA") ?? "localhost:19092",
            ["Exams:Kafka:Topic"] = "exam-submitted-events", ["Exams:Kafka:DeadLetterTopic"] = "exam-submitted-events-dlq",
            ["Exams:Kafka:GroupId"] = "c2-test-" + suffix,
            ["Content:AnimationAllowedHosts:0"] = "animations.example.org",
            ["Jwt:SecretKey"] = jwt.SecretKey, ["Database:MigrateOnStartup"] = "false", ["Auth:SeedAdminOnStartup"] = "false",
            ["Jobs:EnableLegacyMidnight"] = "false", ["Logging:FilePath"] = Path.Combine(Path.GetTempPath(), "c2-tests", suffix + ".jsonl")
        };
        var config = new ConfigurationBuilder().AddInMemoryCollection(settings).Build();
        await using var userDb = new UserDbContext(new DbContextOptionsBuilder<UserDbContext>().UseSqlServer(userConnection).Options);
        await using var contentDb = new ContentDbContext(new DbContextOptionsBuilder<ContentDbContext>().UseSqlServer(contentConnection).Options);
        var userCreated = false;
        var contentCreated = false;
        try
        {
            await userDb.Database.MigrateAsync(); userCreated = true;
            await contentDb.Database.MigrateAsync(); contentCreated = true;
            var admin = new User { Id = Guid.NewGuid(), Username = "test-admin", Email = "admin@fixture.local",
                PasswordHash = new PasswordHasher().HashPassword("Fixture@12345"), Role = UserRole.Admin, CreatedAt = DateTime.UtcNow };
            userDb.Users.Add(admin); await userDb.SaveChangesAsync();
            using var content = new App("Content", settings);
            using var user = new App("User", settings, content, config, jwt);
            using var contentHttp = content.CreateClient();
            using var userHttp = user.CreateClient();
            var tokens = new JwtTokenService(jwt);
            var alice = await Register(userHttp, "alice" + suffix[..8]);
            var bob = await Register(userHttp, "bob" + suffix[..8]);
            contentHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateAccessToken(admin).Token);
            var bank = new ContentBank
            {
                Id = Guid.NewGuid(), Version = "1", Title = "Synthetic C2 integration fixture",
                SourceUrl = "https://example.org/fixture", SourceDescription = "Synthetic test only; no real legal claims",
                Profile = new() { Id = "test", Version = "1", SourceUrl = "https://example.org/profile",
                    DurationSeconds = 60, QuestionCount = 1, PassCount = 1, FailOnCriticalWrong = true },
                Questions = [new() { Id = Guid.NewGuid(), Number = 1, Topic = "test", CategoryType = "SCENARIO", Text = "Synthetic question?",
                    SourceUrl = "https://example.org/question", Explanation = "Secret explanation", IsCritical = true,
                    Options = [new("a", "A"), new("b", "B")], CorrectOptionIds = ["a"],
                    Assets = [new("image", "https://example.org/fixture.png", new string('a', 64), "image/png", "Synthetic image")],
                    ExplanationAnimationUrl = "https://animations.example.org/fixture.html" }]
            };
            var import = await contentHttp.PostAsJsonAsync("/api/admin/question-banks/import", new { bank });
            import.EnsureSuccessStatusCode();
            var preview = (await import.Content.ReadFromJsonAsync<BankPreviewDto>())!;
            var publishPath = $"/api/admin/question-banks/{bank.Id}/versions/1/publish";
            (await contentHttp.PostAsJsonAsync(publishPath, new { expectedHash = preview.Summary.Hash, sourceAndAnswersReviewed = true })).EnsureSuccessStatusCode();
            contentHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateAccessToken(alice).Token);
            var publicJson = await contentHttp.GetStringAsync($"/api/question-banks/{bank.Id}/versions/1/questions");
            Assert.DoesNotContain("correctOption", publicJson, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("Secret explanation", publicJson);
            Assert.Equal(HttpStatusCode.Unauthorized, (await contentHttp.GetAsync($"/internal/content/exam-questions?categoryId={bank.Id}&bankVersion=1&count=1")).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await userHttp.GetAsync("/api/question-banks")).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await contentHttp.GetAsync("/api/auth/profile")).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await userHttp.GetAsync("/exams/")).StatusCode);
            contentHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateContentServiceToken());
            Assert.Equal(HttpStatusCode.Forbidden, (await contentHttp.PostAsync("/internal/content/maintenance", null)).StatusCode);
            contentHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateContentMaintenanceToken());
            (await contentHttp.PostAsync("/internal/content/maintenance", null)).EnsureSuccessStatusCode();
            userHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateAccessToken(alice).Token);
            var create = await userHttp.PostAsJsonAsync("/api/custom-exams", new CreateCustomExam(bank.Id.ToString(), "1", 1, 1));
            create.EnsureSuccessStatusCode();
            var view = (await create.Content.ReadFromJsonAsync<CustomExamView>())!;
            Assert.DoesNotContain("correctOption", await create.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("Secret explanation", await create.Content.ReadAsStringAsync());
            Assert.DoesNotContain("animations.example.org", await create.Content.ReadAsStringAsync());
            Assert.Equal("Synthetic image", Assert.Single(view.Questions[0].Assets!).AltText);
            using var redis = await ConnectionMultiplexer.ConnectAsync(settings["ConnectionStrings:Redis"]!);
            var key = $"custom-exam:v1:{view.ExamId:N}";
            var ttl = await redis.GetDatabase().KeyTimeToLiveAsync(key);
            Assert.True(ttl > TimeSpan.FromDays(7));
            userHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateAccessToken(bob).Token);
            Assert.Equal(HttpStatusCode.Forbidden, (await userHttp.GetAsync($"/api/custom-exams/{view.ExamId}")).StatusCode);
            userHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateAccessToken(alice).Token);
            var saved = await userHttp.PutAsJsonAsync($"/api/custom-exams/{view.ExamId}/answers/{bank.Questions[0].Id}", new { questionId = bank.Questions[0].Id.ToString(), optionId = "a", revision = view.Revision });
            saved.EnsureSuccessStatusCode();
            var reloaded = (await saved.Content.ReadFromJsonAsync<CustomExamView>())!;
            Assert.Equal(view.DeadlineUtc, reloaded.DeadlineUtc);
            Assert.True(await redis.GetDatabase().KeyTimeToLiveAsync(key) <= ttl);
            var submit = await userHttp.PostAsync($"/api/custom-exams/{view.ExamId}/submit", null);
            submit.EnsureSuccessStatusCode();
            var score = (await submit.Content.ReadFromJsonAsync<ExamScore>())!;
            Assert.Equal(1, score.Correct);
            (await userHttp.PostAsync($"/api/custom-exams/{view.ExamId}/submit", null)).EnsureSuccessStatusCode();
            Assert.Equal(1, await userDb.ExamAttempts.CountAsync(a => a.Id == score.AttemptId));
            var attempt = await userDb.ExamAttempts.AsNoTracking().SingleAsync(a => a.Id == score.AttemptId);
            Assert.True(attempt.IsPassed);
            var result = System.Text.Json.JsonSerializer.Deserialize<SaveExamResult>(attempt.ExamSnapshotJson)!;
            // Identical concurrent retries succeed; conflicting reuse must fail.
            var internalHttp = user.CreateClient();
            internalHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateExamServiceToken());
            var repeats = await Task.WhenAll(Enumerable.Range(0, 4).Select(_ => internalHttp.PostAsJsonAsync("/internal/user/exam-results", result)));
            Assert.All(repeats, response => Assert.Equal(HttpStatusCode.OK, response.StatusCode));
            var changed = result with { SubmittedAtUtc = result.SubmittedAtUtc.AddSeconds(1) };
            Assert.Equal(HttpStatusCode.Conflict, (await internalHttp.PostAsJsonAsync("/internal/user/exam-results", changed)).StatusCode);
            var inbox = new RedisNotificationInbox(redis);
            using var producer = new ProducerBuilder<string, string>(new ProducerConfig { BootstrapServers = settings["Exams:Kafka:BootstrapServers"] }).Build();
            using var worker = new ExamNotificationWorker(config, producer, inbox, NullLogger<ExamNotificationWorker>.Instance);
            var starting = Task.Run(() => worker.StartAsync(CancellationToken.None));
            try
            {
                for (var i = 0; i < 100 && (await inbox.GetRecentAsync(alice.Id, default)).Count == 0; i++) await Task.Delay(200);
                Assert.Single(await inbox.GetRecentAsync(alice.Id, default));
                Assert.Empty(await inbox.GetRecentAsync(bob.Id, default));
            }
            finally { await worker.StopAsync(new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token); await starting; }
            await redis.GetDatabase().KeyDeleteAsync(key);
            Assert.Equal(HttpStatusCode.NotFound, (await userHttp.GetAsync($"/api/custom-exams/{view.ExamId}")).StatusCode);
            var review = await userHttp.GetAsync($"/api/exam-attempts/{score.AttemptId}");
            review.EnsureSuccessStatusCode(); Assert.Contains("Synthetic question?", await review.Content.ReadAsStringAsync());
            Assert.Contains("animations.example.org", await review.Content.ReadAsStringAsync());
            userHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateAccessToken(bob).Token);
            Assert.Equal(HttpStatusCode.NotFound, (await userHttp.GetAsync($"/api/exam-attempts/{score.AttemptId}")).StatusCode);
            userHttp.DefaultRequestHeaders.Authorization = new("Bearer", tokens.CreateAccessToken(alice).Token);
            var progress = await userHttp.GetStringAsync($"/api/learning/progress/{bank.Id}");
            Assert.Contains("\"answeredQuestions\":1", progress);
            (await userHttp.GetAsync("/api/account/quota")).EnsureSuccessStatusCode();
            (await userHttp.GetAsync("/api/reports/usage")).EnsureSuccessStatusCode();
        }
        finally
        {
            // Both names are generated above and point only to isolated test databases.
            if (userCreated) await userDb.Database.EnsureDeletedAsync();
            if (contentCreated) await contentDb.Database.EnsureDeletedAsync();
        }
    }

    private static async Task<User> Register(HttpClient client, string name)
    {
        var response = await client.PostAsJsonAsync("/api/auth/register", new { username = name, email = name + "@fixture.local", password = "Fixture@12345" });
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>();
        return new User { Id = json.GetProperty("user").GetProperty("id").GetGuid(), Username = name, Email = name + "@fixture.local", PasswordHash = "unused", Role = UserRole.User };
    }

    private sealed class App(string module, Dictionary<string, string?> settings, App? content = null,
        IConfiguration? config = null, JwtSettings? jwt = null) : WebApplicationFactory<Program>
    {
        protected override IHost CreateHost(IHostBuilder builder)
        {
            builder.ConfigureHostConfiguration(c => c.AddInMemoryCollection(settings.Append(new("Service:Module", module))));
            return base.CreateHost(builder);
        }
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            if (content is not null) builder.ConfigureTestServices(services =>
            {
                services.AddScoped<IExamQuestionSource>(_ => new ContentQuestionClient(content.CreateClient(), config!, new JwtTokenService(jwt!)));
                services.AddScoped<ILearningCatalogClient>(_ => new LearningCatalogHttpClient(content.CreateClient(), new JwtTokenService(jwt!)));
            });
        }
    }
}
