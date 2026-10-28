using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace ChatAIWeb.Tests.AccountLearning;

// Runs the real REST host (JWT, controllers, ProblemDetails, EF migrations) against a throwaway SQL Server database.
[Collection(AccountLearningCollection.Name)]
public sealed class AccountApiTests : IClassFixture<SqlServerDatabase>, IAsyncLifetime
{
    private readonly SqlServerDatabase database;
    private readonly string adminEmail = $"admin-{Guid.NewGuid():N}@test.local";
    private readonly string adminPassword = Convert.ToBase64String(RandomNumberGenerator.GetBytes(18));
    private readonly string tempRoot = Path.Combine(Path.GetTempPath(), "bao-api-tests", Guid.NewGuid().ToString("N"));
    private readonly Dictionary<string, string?> previousEnvironment = new();
    private WebApplicationFactory<Program> factory = null!;

    public AccountApiTests(SqlServerDatabase database) => this.database = database;

    public Task InitializeAsync()
    {
        // Program reads these while building the host, so they are passed as environment variables.
        SetEnvironment("ConnectionStrings__DefaultConnection", database.ConnectionString);
        SetEnvironment("Jwt__SecretKey", Convert.ToBase64String(RandomNumberGenerator.GetBytes(48)));
        SetEnvironment("Database__MigrateOnStartup", "true");
        // Each test builds its own host on the shared database, so each seeds a distinct admin.
        SetEnvironment("Auth__SeedAdmin__Username", "admin" + Guid.NewGuid().ToString("N")[..10]);
        SetEnvironment("Auth__SeedAdmin__Email", adminEmail);
        SetEnvironment("Auth__SeedAdmin__Password", adminPassword);
        SetEnvironment("Quota__RecoveryEnabled", "false");
        SetEnvironment("Jobs__EnableLegacyMidnight", "false");
        SetEnvironment("Chat__AttachmentRoot", Path.Combine(tempRoot, "attachments"));
        SetEnvironment("Logging__FilePath", Path.Combine(tempRoot, "rest-api.jsonl"));
        factory = new WebApplicationFactory<Program>();
        return Task.CompletedTask;
    }

    public async Task DisposeAsync()
    {
        await factory.DisposeAsync();
        foreach (var (name, value) in previousEnvironment)
        {
            Environment.SetEnvironmentVariable(name, value);
        }

        if (Directory.Exists(tempRoot))
        {
            Directory.Delete(tempRoot, true);
        }
    }

    private void SetEnvironment(string name, string value)
    {
        previousEnvironment.TryAdd(name, Environment.GetEnvironmentVariable(name));
        Environment.SetEnvironmentVariable(name, value);
    }

    private async Task<JsonElement> RegisterAsync(HttpClient client, string password = "Password@123")
    {
        var name = "u" + Guid.NewGuid().ToString("N")[..12];
        var response = await client.PostAsJsonAsync("/api/auth/register",
            new { username = name, email = $"{name}@test.local", password });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    private static HttpRequestMessage Authorized(HttpMethod method, string url, JsonElement auth)
    {
        var request = new HttpRequestMessage(method, url);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", auth.GetProperty("accessToken").GetString());
        return request;
    }

    [Fact]
    public async Task LoginRefreshAndLogoutWithoutTokenTable()
    {
        var client = factory.CreateClient();
        var registered = await RegisterAsync(client);
        var email = registered.GetProperty("user").GetProperty("email").GetString();

        var wrong = await client.PostAsJsonAsync("/api/auth/login", new { email, password = "Wrong@12345" });
        Assert.Equal(HttpStatusCode.Unauthorized, wrong.StatusCode);
        Assert.Equal("application/problem+json", wrong.Content.Headers.ContentType?.MediaType);

        var login = await (await client.PostAsJsonAsync("/api/auth/login", new { email, password = "Password@123" }))
            .Content.ReadFromJsonAsync<JsonElement>();

        var profile = await client.SendAsync(Authorized(HttpMethod.Get, "/api/auth/profile", login));
        Assert.Equal(HttpStatusCode.OK, profile.StatusCode);
        Assert.Equal(email, (await profile.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("email").GetString());
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/auth/profile")).StatusCode);

        var accessToken = login.GetProperty("accessToken").GetString();
        var oldRefresh = login.GetProperty("refreshToken").GetString()!;
        var rotated = await client.PostAsJsonAsync("/api/auth/refresh-token", new { refreshToken = oldRefresh });
        Assert.Equal(HttpStatusCode.OK, rotated.StatusCode);
        var newRefresh = (await rotated.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("refreshToken").GetString();
        Assert.NotEqual(oldRefresh, newRefresh);

        // Token types are not interchangeable: an access token is not a refresh token and vice versa.
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/api/auth/refresh-token", new { refreshToken = accessToken })).StatusCode);
        var refreshAsBearer = new HttpRequestMessage(HttpMethod.Get, "/api/auth/profile");
        refreshAsBearer.Headers.Authorization = new AuthenticationHeaderValue("Bearer", oldRefresh);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.SendAsync(refreshAsBearer)).StatusCode);

        // A tampered signature is rejected.
        var tampered = oldRefresh[..^2] + (oldRefresh[^2] == 'A' ? "BB" : "AA");
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.PostAsJsonAsync("/api/auth/refresh-token", new { refreshToken = tampered })).StatusCode);

        // Logout is client-side (no token table): always 204 and idempotent.
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.PostAsJsonAsync("/api/auth/logout", new { refreshToken = newRefresh })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent,
            (await client.PostAsJsonAsync("/api/auth/logout", new { refreshToken = newRefresh })).StatusCode);
    }

    [Fact]
    public async Task UsersCannotReachEachOthersData()
    {
        var client = factory.CreateClient();
        var alice = await RegisterAsync(client);
        var bob = await RegisterAsync(client);

        var create = Authorized(HttpMethod.Post, "/api/chats", alice);
        create.Content = JsonContent.Create(new { title = "Alice" });
        var created = await client.SendAsync(create);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var sessionId = (await created.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetString();

        Assert.Equal(HttpStatusCode.OK, (await client.SendAsync(Authorized(HttpMethod.Get, $"/api/chats/{sessionId}", alice))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.SendAsync(Authorized(HttpMethod.Get, $"/api/chats/{sessionId}", bob))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.SendAsync(Authorized(HttpMethod.Delete, $"/api/chats/{sessionId}", bob))).StatusCode);

        var aliceId = alice.GetProperty("user").GetProperty("id").GetString();
        var bobAsksAlice = await client.SendAsync(Authorized(HttpMethod.Get, $"/api/reports/usage?userId={aliceId}", bob));
        Assert.Equal(HttpStatusCode.Forbidden, bobAsksAlice.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/learning/progress")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/reports/usage")).StatusCode);
    }

    [Fact]
    public async Task ProgressQuotaAndReportsOverHttp()
    {
        var client = factory.CreateClient();
        var user = await RegisterAsync(client);
        var userId = Guid.Parse(user.GetProperty("user").GetProperty("id").GetString()!);
        var seed = new LearningSeed();
        await using (var db = database.CreateContext())
        {
            await seed.AddBanksAsync(db);
            await seed.AddAttemptsAsync(db, userId);
        }

        var overview = await (await client.SendAsync(Authorized(HttpMethod.Get, "/api/learning/progress", user)))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains(overview.EnumerateArray(), b => b.GetProperty("bankId").GetGuid() == seed.BankId);
        Assert.DoesNotContain(overview.EnumerateArray(), b => b.GetProperty("bankId").GetGuid() == seed.DraftBankId);

        var detail = await (await client.SendAsync(Authorized(HttpMethod.Get, $"/api/learning/progress/{seed.BankId}", user)))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(3, detail.GetProperty("answeredQuestions").GetInt32());
        Assert.Equal(1, detail.GetProperty("unseenQuestions").GetInt32());

        var bookmark = await client.SendAsync(Authorized(HttpMethod.Put, $"/api/learning/bookmarks/{seed.Questions[2]}", user));
        Assert.Equal(HttpStatusCode.NoContent, bookmark.StatusCode);
        var bookmarks = await (await client.SendAsync(Authorized(HttpMethod.Get, "/api/learning/bookmarks", user)))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, bookmarks.GetProperty("totalCount").GetInt32());

        var history = await (await client.SendAsync(Authorized(HttpMethod.Get, "/api/learning/history?mode=Exam", user)))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(2, history.GetProperty("totalCount").GetInt32());

        var quota = await (await client.SendAsync(Authorized(HttpMethod.Get, "/api/account/quota", user)))
            .Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(quota.GetProperty("tokenBalance").GetInt32(), quota.GetProperty("availableTokens").GetInt32());

        var usage = await client.SendAsync(Authorized(HttpMethod.Get, "/api/reports/usage", user));
        Assert.Equal(HttpStatusCode.OK, usage.StatusCode);
        Assert.Equal("User", (await usage.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("scope").GetString());

        var admin = await (await client.PostAsJsonAsync("/api/auth/login", new { email = adminEmail, password = adminPassword }))
            .Content.ReadFromJsonAsync<JsonElement>();
        var all = await client.SendAsync(Authorized(HttpMethod.Get, $"/api/reports/usage?userId={userId}", admin));
        Assert.Equal(HttpStatusCode.OK, all.StatusCode);
        Assert.Equal("User", (await all.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("scope").GetString());
        var bad = await client.SendAsync(Authorized(HttpMethod.Get, "/api/reports/usage?from=2026-10-10&to=2026-10-01", admin));
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
    }
}
