using System.Net;
using System.Net.Http.Json;
using BusinessLogic.Exceptions;
using BusinessLogic.Exams;
using Microsoft.Extensions.Configuration;

namespace BusinessLogic.Tests;

public sealed class ExamContentErrorTests
{
    [Theory]
    [InlineData(400, false)] [InlineData(400, true)]
    [InlineData(409, false)] [InlineData(409, true)]
    [InlineData(503, false)] [InlineData(503, true)]
    public async Task ContentPolicyErrorsRetainTheirPublicStatus(int status, bool template)
    {
        using var http = new HttpClient(new Handler((HttpStatusCode)status)) { BaseAddress = new Uri("http://fixture.local/") };
        var source = new ContentQuestionClient(http, new ConfigurationBuilder().Build());
        var exception = await Assert.ThrowsAnyAsync<AppException>(async () =>
        {
            if (template) await source.GetTemplateAsync("test", 1, default);
            else await source.GetQuestionsAsync(Guid.NewGuid().ToString(), "1", 30, default);
        });
        Assert.Equal(status, exception.StatusCode);
    }

    private sealed class Handler(HttpStatusCode status) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(new HttpResponseMessage(status) { Content = JsonContent.Create(new { detail = "Quy định của profile không cho phép thông số đã chọn." }) });
    }
}
