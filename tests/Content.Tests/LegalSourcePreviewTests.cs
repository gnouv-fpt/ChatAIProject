using System.Net;
using System.Text;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Implementations;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Content.Tests;

public sealed class LegalSourcePreviewTests
{
    private const string Source = "https://thuvienphapluat.vn/van-ban/test.aspx";
    private static string Html => "<h1>Văn bản kiểm thử</h1><p>Số: 01/TEST</p><div id='divContentDoc'><p>Điều 1. Kiểm thử</p><p>1. Nội dung khoản</p><p>a) " + new string('x', 150) + "</p><p>b) Nội dung điểm tiếp</p></div>";

    [Fact]
    public async Task PreviewRetainsEvidenceHashesUtcAndPointSequenceWithoutActivatingRag()
    {
        var handler = new SourceHandler(_ => new(HttpStatusCode.OK) { Content = new StringContent(Html, Encoding.UTF8, "text/html") });
        using var client = new HttpClient(handler);
        var preview = await Service(client).PreviewAsync(Source);
        Assert.Equal("01/TEST", preview.DocumentNumber);
        Assert.Equal(DateTimeKind.Utc, preview.RetrievedAtUtc.Kind);
        Assert.Equal(64, preview.HtmlSha256.Length); Assert.Equal(64, preview.ContentSha256.Length);
        Assert.NotEqual(preview.HtmlSha256, preview.ContentSha256);
        Assert.Contains(preview.Chunks, c => c.Article == "1" && c.Clause == "1" && c.Point == "a");
        Assert.Contains(preview.Chunks, c => c.Article == "1" && c.Clause == "1" && c.Point == "b");
        Assert.Equal(Enumerable.Range(0, preview.Chunks.Count), preview.Chunks.Select(c => c.Sequence));
        Assert.Equal(1, handler.Calls);
    }

    [Theory]
    [InlineData("https://evil.org/van-ban/test.aspx")]
    [InlineData("https://thuvienphapluat.vn.evil.org/van-ban/test.aspx")]
    [InlineData("https://thuvienphapluat.vn/van-ban/test.aspx?token=secret")]
    [InlineData("https://thuvienphapluat.vn/van-ban/test.aspx#section")]
    [InlineData("https://thuvienphapluat.vn/van-ban/../test.aspx")]
    public async Task DisallowedSourceIsRejectedBeforeNetwork(string source)
    {
        var handler = new SourceHandler(_ => throw new Exception("Network must not be called"));
        using var client = new HttpClient(handler);
        await Assert.ThrowsAsync<BadRequestException>(() => Service(client).PreviewAsync(source));
        Assert.Equal(0, handler.Calls);
    }

    [Theory]
    [InlineData(HttpStatusCode.Redirect, 400)]
    [InlineData(HttpStatusCode.Forbidden, 502)]
    [InlineData(HttpStatusCode.ServiceUnavailable, 502)]
    public async Task ProviderErrorsAndRedirectsAreNotContent(HttpStatusCode status, int expected)
    {
        using var client = new HttpClient(new SourceHandler(_ => new(status)));
        var exception = await Assert.ThrowsAnyAsync<AppException>(() => Service(client).PreviewAsync(Source));
        Assert.Equal(expected, exception.StatusCode);
    }

    [Fact]
    public async Task IncorrectMediaTypeAndInvalidUtf8AreRejected()
    {
        using var wrongType = new HttpClient(new SourceHandler(_ => new(HttpStatusCode.OK) { Content = new StringContent("{}", Encoding.UTF8, "application/json") }));
        await Assert.ThrowsAsync<BadRequestException>(() => Service(wrongType).PreviewAsync(Source));
        using var badEncoding = new HttpClient(new SourceHandler(_ => {
            var content = new ByteArrayContent([0xff, 0xfe]);
            content.Headers.ContentType = new("text/html") { CharSet = "utf-8" };
            return new(HttpStatusCode.OK) { Content = content };
        }));
        await Assert.ThrowsAsync<BadRequestException>(() => Service(badEncoding).PreviewAsync(Source));
    }

    [Fact]
    public async Task OversizeContentIsRejectedAndCancellationPropagates()
    {
        using var tooLarge = new HttpClient(new SourceHandler(_ => {
            var content = new StringContent(Html, Encoding.UTF8, "text/html");
            content.Headers.ContentLength = 8 * 1024 * 1024 + 1;
            return new(HttpStatusCode.OK) { Content = content };
        }));
        await Assert.ThrowsAsync<BadRequestException>(() => Service(tooLarge).PreviewAsync(Source));
        using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Service(tooLarge).PreviewAsync(Source, cancelled.Token));
    }

    private static LegalSourcePreviewService Service(HttpClient client) => new(client, NullLogger<LegalSourcePreviewService>.Instance);
    private sealed class SourceHandler(Func<HttpRequestMessage, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public int Calls { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested(); Calls++;
            var response = respond(request); response.RequestMessage = request;
            return Task.FromResult(response);
        }
    }
}
