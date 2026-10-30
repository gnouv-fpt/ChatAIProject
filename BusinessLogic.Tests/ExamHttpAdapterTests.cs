using System.Net;
using System.Net.Http.Json;
using BusinessLogic.Exams;
using BusinessLogic.Exceptions;
using Microsoft.Extensions.Configuration;

namespace BusinessLogic.Tests;

public sealed class ExamHttpAdapterTests
{
    [Fact]
    public async Task Content_client_requests_server_only_questions_with_internal_key()
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = JsonContent.Create(new[]
            {
                new BankQuestion("q1", "v1", "Question", [new("a", "A"), new("b", "B")], "a")
            })
        });
        var client = new ContentQuestionClient(new HttpClient(handler)
        {
            BaseAddress = new Uri("http://content.local/")
        }, Config());
        var questions = await client.GetQuestionsAsync("signs & rules", "v1", 1, default);
        Assert.Single(questions);
        Assert.Equal("a", questions[0].CorrectOptionId);
        Assert.Contains("categoryId=signs%20%26%20rules", handler.LastUri?.Query);
        Assert.Equal("shared-test-key", handler.LastKey);
    }

    [Fact]
    public async Task Result_client_propagates_conflicting_attempt()
    {
        var handler = new StubHandler(_ => new HttpResponseMessage(HttpStatusCode.Conflict));
        var client = new UserExamResultClient(new HttpClient(handler)
        {
            BaseAddress = new Uri("http://user.local/")
        }, Config());
        var result = new SaveExamResult(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), "v1",
            DateTimeOffset.UtcNow, 0, 0, []);
        await Assert.ThrowsAsync<ConflictException>(() => client.SaveAsync(result, default));
        Assert.Equal("shared-test-key", handler.LastKey);
    }

    private static IConfiguration Config() => new ConfigurationBuilder().AddInMemoryCollection(
        new Dictionary<string, string?>
        {
            ["Exams:ContentQuestionsPath"] = "api/internal/exam-questions",
            ["Exams:SaveResultPath"] = "api/internal/exam-results",
            ["Exams:InternalApiKey"] = "shared-test-key"
        }).Build();

    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> reply) : HttpMessageHandler
    {
        public Uri? LastUri { get; private set; }
        public string? LastKey { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            LastUri = request.RequestUri;
            LastKey = request.Headers.GetValues("X-Internal-Api-Key").Single();
            return Task.FromResult(reply(request));
        }
    }
}
