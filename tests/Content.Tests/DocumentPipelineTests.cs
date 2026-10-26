using System.Net;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess;
using DataAccess.Repositories.Implementations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Content.Tests;

public sealed class DocumentPipelineTests
{
    private static ChatAIWebDbContext Database() => new(new DbContextOptionsBuilder<ChatAIWebDbContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    [Fact]
    public async Task CrawlPersistsContentPendingAndDeduplicatesBySource()
    {
        await using var db = Database();
        using var client = new HttpClient(new SourceHandler());
        var service = new CrawlerService(client, new DocumentRepository(db), new GenericRepository<DocumentChunk>(db), NullLogger<CrawlerService>.Instance);
        await service.CrawlTrafficLawsAsync();
        Assert.Single(await db.LegalDocuments.ToListAsync());
        var document = await db.LegalDocuments.SingleAsync();
        Assert.Equal("01/TEST", document.DocumentNumber);
        Assert.False(document.IsActive);
        Assert.Equal(VerificationStatus.Pending, document.VerificationStatus);
        Assert.All(await db.DocumentChunks.ToListAsync(), c => { Assert.False(c.IsVerified); Assert.False(string.IsNullOrWhiteSpace(c.Content)); });
        await service.CrawlTrafficLawsAsync();
        Assert.Single(await db.LegalDocuments.ToListAsync());
    }

    [Theory]
    [InlineData(false, "Verified", true, 2, false)]
    [InlineData(true, "Pending", true, 2, false)]
    [InlineData(true, "Verified", false, 0, false)]
    [InlineData(true, "Verified", true, 1, false)]
    [InlineData(true, "Verified", true, 2, true)]
    public async Task IndexOnlyActivatesAfterVerificationAndCompleteAck(bool valid, string status, bool success, int count, bool activated)
    {
        await using var db = Database();
        var id = Guid.NewGuid();
        const string source = "https://thuvienphapluat.vn/van-ban/test.aspx";
        db.LegalDocuments.Add(new() { Id = id, DocumentNumber = "test", Title = "test", SourceUrl = source });
        db.DocumentChunks.AddRange(new DocumentChunk { Id = Guid.NewGuid(), DocumentId = id, Content = "one" },
            new DocumentChunk { Id = Guid.NewGuid(), DocumentId = id, Content = "two" });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        var service = new DocumentIndexService(new DocumentRepository(db), new GenericRepository<DocumentChunk>(db),
            new Inference(valid, status, success, count), NullLogger<DocumentIndexService>.Instance,
            new ContentPipelineSettings { EnableVerifiedIndexing = true });
        var request = new VerifyDocumentRequestDto { EvidenceUrl = source, EffectiveDate = DateTime.UtcNow.AddDays(-1),
            ReviewNotes = "TEST: source and amendments reviewed", SourceAndAmendmentsReviewed = true };
        if (activated) await service.VerifyAndIndexAsync(id, request);
        else await Assert.ThrowsAnyAsync<AppException>(() => service.VerifyAndIndexAsync(id, request));
        Assert.Equal(activated, (await db.LegalDocuments.SingleAsync()).IsActive);
        Assert.All(await db.DocumentChunks.ToListAsync(), c => Assert.Equal(activated, c.IsVerified));
    }

    [Fact]
    public async Task IndexIsDisabledUntilCrossServiceContractsAreIntegrated()
    {
        await using var db = Database();
        var service = new DocumentIndexService(new DocumentRepository(db), new GenericRepository<DocumentChunk>(db),
            new Inference(false, "Pending", false, 0), NullLogger<DocumentIndexService>.Instance, new());
        var exception = await Assert.ThrowsAsync<AppException>(() => service.VerifyAndIndexAsync(Guid.NewGuid(), new()));
        Assert.Equal(503, exception.StatusCode);
    }

    private sealed class SourceHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var html = request.RequestUri!.AbsolutePath.EndsWith(".aspx") ?
                "<h1>Văn bản kiểm thử</h1><p>Số: 01/TEST</p><div id='divContentDoc'><p>Điều 1. Phạm vi</p><p>1. " + new string('x', 150) + "</p></div>" :
                "<a href='/van-ban/test.aspx'>Test</a><a href='https://evil.org/van-ban/test.aspx'>Excluded</a>";
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { RequestMessage = request, Content = new StringContent(html) });
        }
    }
    private sealed class Inference(bool valid, string status, bool success, int count) : IGrpcInferenceService
    {
        public Task<ChatInferenceResultDto> ProcessChatMessageAsync(string userId, string sessionId, string prompt, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<VerificationResultDto> VerifyLegalDocumentAsync(string documentTitle, string documentNumber, string content, CancellationToken cancellationToken = default) => Task.FromResult(new VerificationResultDto { IsValid = valid, Status = status });
        public Task<IndexDocumentResultDto> IndexDocumentAsync(IEnumerable<DocumentChunkInputDto> chunks, CancellationToken cancellationToken = default) => Task.FromResult(new IndexDocumentResultDto { Success = success, IndexedCount = count });
    }
}
