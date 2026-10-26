using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using BusinessLogic.DTOs;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Presentation.BackgroundJobs;
using Xunit;

namespace Content.Tests;

public sealed class ContentApiTests
{
    [Fact]
    public async Task HttpPermissionsValidationAndPublishedProjection()
    {
        using var app = new ContentApp(); using var client = app.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/question-banks")).StatusCode);
        client.DefaultRequestHeaders.Add("TestRole", "User");
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/admin/question-banks")).StatusCode);
        client.DefaultRequestHeaders.Remove("TestRole"); client.DefaultRequestHeaders.Add("TestRole", "Admin");
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/admin/question-banks/import", new { })).StatusCode);
        var bank = QuestionBankTests.Fixture();
        var response = await client.PostAsJsonAsync("/api/admin/question-banks/import", new { bank });
        response.EnsureSuccessStatusCode();
        var preview = (await response.Content.ReadFromJsonAsync<BankPreviewDto>())!;
        var path = $"/api/admin/question-banks/{bank.Id}/versions/{bank.Version}";
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync(path + "/publish",
            new { expectedHash = preview.Summary.Hash, sourceAndAnswersReviewed = false })).StatusCode);
        (await client.PostAsJsonAsync(path + "/publish", new { expectedHash = preview.Summary.Hash, sourceAndAnswersReviewed = true })).EnsureSuccessStatusCode();
        client.DefaultRequestHeaders.Remove("TestRole"); client.DefaultRequestHeaders.Add("TestRole", "User");
        var questions = await client.GetStringAsync($"/api/question-banks/{bank.Id}/versions/{bank.Version}/questions");
        Assert.DoesNotContain("correctOptionIds", questions);
        Assert.DoesNotContain("explanation", questions);
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync(path + "/preview")).StatusCode);
        var problem = await client.GetAsync($"/api/question-banks/{bank.Id}/versions/{bank.Version}/questions?pageSize=0");
        Assert.Equal(HttpStatusCode.BadRequest, problem.StatusCode);
        Assert.Equal("application/problem+json", problem.Content.Headers.ContentType?.MediaType);
    }

    private sealed class ContentApp : WebApplicationFactory<Program>
    {
        private readonly string _root = Path.Combine(Path.GetTempPath(), "content-api-" + Guid.NewGuid().ToString("N"));
        protected override IHost CreateHost(IHostBuilder builder)
        {
            builder.ConfigureHostConfiguration(config => config.AddInMemoryCollection(new Dictionary<string, string?> {
                ["Database:MigrateOnStartup"] = "false", ["Jwt:SecretKey"] = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32)),
                ["Content:BankStoragePath"] = _root }));
            return base.CreateHost(builder);
        }
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.ConfigureTestServices(services => {
                var job = services.FirstOrDefault(s => s.ServiceType == typeof(IHostedService) && s.ImplementationType == typeof(MidnightCleanupJob));
                if (job is not null) services.Remove(job);
                services.AddAuthentication(options => { options.DefaultAuthenticateScheme = "Test"; options.DefaultChallengeScheme = "Test"; options.DefaultForbidScheme = "Test"; })
                    .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>("Test", _ => { });
            });
        }
        protected override void Dispose(bool disposing) { base.Dispose(disposing); if (disposing && Directory.Exists(_root)) Directory.Delete(_root, true); }
    }

    private sealed class TestAuthHandler(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var role = Request.Headers["TestRole"].ToString();
            if (role.Length == 0) return Task.FromResult(AuthenticateResult.NoResult());
            var identity = new ClaimsIdentity([new Claim("sub", Guid.NewGuid().ToString()), new Claim(ClaimTypes.Role, role)], Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(new(new ClaimsPrincipal(identity), Scheme.Name)));
        }
    }
}
