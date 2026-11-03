using System.Security.Cryptography;
using System.Text;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess;
using DataAccess.Repositories.Implementations;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Content.Tests;

public sealed class LegalCorpusExtensionTests
{
    [Fact]
    public async Task EditionFourFailuresKeepEditionThreeEligibleAndRetryCompletes()
    {
        await using var db = new ContentDbContext(new DbContextOptionsBuilder<ContentDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var documentId = Guid.NewGuid();
        const string source = "https://thuvienphapluat.vn/van-ban/test.aspx";
        const string originalHash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        db.LegalDocuments.Add(new LegalDocument { Id = documentId, DocumentNumber = "55/VBHN-VPQH",
            Title = "VBHN 55 · trích Điều 1–55", SourceUrl = source, ContentHash = originalHash,
            Version = 3, IsActive = true, VerificationStatus = VerificationStatus.Verified,
            EffectiveDate = DateTime.UtcNow.AddDays(-1), CreatedAt = DateTime.UtcNow });
        var originalIds = Enumerable.Range(0, 596).Select(_ => Guid.NewGuid()).ToArray();
        db.DocumentChunks.AddRange(originalIds.Select((id, index) => new DocumentChunk { Id = id,
            DocumentId = documentId, Article = (index % 55 + 1).ToString(), Content = $"Existing {index}", IsVerified = true }));
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        var inference = new FailingEditionFourInference();
        var service = new LegalCorpusExtensionService(new DocumentRepository(db),
            new GenericRepository<DocumentChunk>(db), inference);
        var content = string.Join("\n", Enumerable.Range(56, 34).Select(n =>
            $"Điều {n}. Dữ liệu tổng hợp chỉ dùng để kiểm thử.\n1. Nội dung giả không phải căn cứ pháp luật."));
        var capture = new ImportCapturedLegalCorpusRequest(source, "55/VBHN-VPQH", "Synthetic test",
            content, Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(content))),
            Enumerable.Range(56, 34).Select(n => n.ToString()).ToArray(),
            "https://datafiles.chinhphu.vn/test.pdf", "Synthetic test only; never activate outside test.");
        var request = new ExtendReviewedCorpusRequest(capture, originalHash, 3);

        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.ExtendAsync(request, default));
        db.ChangeTracker.Clear();
        Assert.Equal(3, (await db.LegalDocuments.SingleAsync()).Version);
        Assert.True((await db.LegalDocuments.SingleAsync()).IsActive);
        Assert.All(await db.DocumentChunks.Where(c => originalIds.Contains(c.Id)).ToListAsync(), c => Assert.True(c.IsVerified));
        db.ChangeTracker.Clear();
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.ExtendAsync(request, default));
        db.ChangeTracker.Clear();
        Assert.Equal(4, (await db.LegalDocuments.SingleAsync()).Version);
        Assert.True((await db.LegalDocuments.SingleAsync()).IsActive);
        Assert.All(await db.DocumentChunks.Where(c => originalIds.Contains(c.Id)).ToListAsync(), c => Assert.True(c.IsVerified));
        Assert.All(await db.DocumentChunks.Where(c => !originalIds.Contains(c.Id)).ToListAsync(), c => Assert.Null(c.VectorId));
        db.ChangeTracker.Clear();

        var result = await service.ExtendAsync(request, default);
        db.ChangeTracker.Clear();
        Assert.Equal(4, result.Version);
        Assert.Equal(596 + result.AddedChunkCount, result.ChunkCount);
        Assert.Contains("Điều 1–89", (await db.LegalDocuments.SingleAsync()).Title);
        Assert.All(await db.DocumentChunks.ToListAsync(), c => Assert.True(c.IsVerified));
        Assert.All(await db.DocumentChunks.Where(c => !originalIds.Contains(c.Id)).ToListAsync(),
            c => Assert.NotNull(c.VectorId));
        Assert.Equal(result, await service.ExtendAsync(request, default));
        Assert.Equal(8, inference.IndexCalls);
        Assert.Equal(5, inference.VerifyCalls);
        Assert.Equal(0, inference.DeactivateCalls);
    }

    [Theory]
    [InlineData(1, 33, 34, 16)]
    [InlineData(2, 49, 50, 6)]
    public async Task FailedIndexLeavesSqlIneligibleAndRetryPreservesOriginalChunkIds(
        int currentVersion, int existingArticles, int firstNewArticle, int newArticles)
    {
        await using var db = new ContentDbContext(new DbContextOptionsBuilder<ContentDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var documentId = Guid.NewGuid();
        var originalIds = Enumerable.Range(1, existingArticles).Select(_ => Guid.NewGuid()).ToArray();
        const string source = "https://thuvienphapluat.vn/van-ban/test.aspx";
        const string originalHash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
        db.LegalDocuments.Add(new LegalDocument { Id = documentId, DocumentNumber = "55/VBHN-VPQH",
            Title = "Reviewed source · trích Điều 1–33", SourceUrl = source, ContentHash = originalHash,
            Version = currentVersion, IsActive = true, VerificationStatus = VerificationStatus.Verified,
            EffectiveDate = DateTime.UtcNow.AddDays(-1), CreatedAt = DateTime.UtcNow });
        db.DocumentChunks.AddRange(Enumerable.Range(1, existingArticles).Select(n => new DocumentChunk {
            Id = originalIds[n - 1], DocumentId = documentId, Article = n.ToString(),
            Content = $"Điều {n}. Nội dung cũ", IsVerified = true }));
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        var inference = new FailingOnceInference();
        var service = new LegalCorpusExtensionService(new DocumentRepository(db), new GenericRepository<DocumentChunk>(db), inference);
        var content = string.Join("\n", Enumerable.Range(firstNewArticle, newArticles).Select(n =>
            $"Điều {n}. Nội dung tổng hợp chỉ dùng cho kiểm thử, không được coi là căn cứ pháp luật.\n" +
            "1. Đây là đoạn dữ liệu giả dùng để kiểm tra khả năng phục hồi khi lập chỉ mục Qdrant thất bại.\n" +
            "a) Trạng thái SQL phải ngừng cho phép trích dẫn trong lúc thao tác chờ chạy lại."));
        var capture = new ImportCapturedLegalCorpusRequest(source, "55/VBHN-VPQH", "Synthetic test",
            content, Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(content))),
            Enumerable.Range(firstNewArticle, newArticles).Select(n => n.ToString()).ToArray(),
            "https://datafiles.chinhphu.vn/test.pdf", "Synthetic test only; never activate outside test.");
        var request = new ExtendReviewedCorpusRequest(capture, originalHash, currentVersion);

        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.ExtendAsync(request, default));
        db.ChangeTracker.Clear();
        var staged = await db.LegalDocuments.SingleAsync();
        Assert.False(staged.IsActive);
        Assert.Equal(currentVersion + 1, staged.Version);
        Assert.All(await db.DocumentChunks.ToListAsync(), c => Assert.False(c.IsVerified));
        Assert.All(originalIds, id => Assert.Contains(id, db.DocumentChunks.Select(c => c.Id)));
        db.ChangeTracker.Clear();

        var result = await service.ExtendAsync(request, default);
        db.ChangeTracker.Clear();
        Assert.True(result.IsActive);
        Assert.Equal(currentVersion + 1, result.Version);
        Assert.Equal(existingArticles + result.AddedChunkCount, await db.DocumentChunks.CountAsync());
        Assert.All(originalIds, id => Assert.Contains(id, db.DocumentChunks.Select(c => c.Id)));
        Assert.All(await db.DocumentChunks.ToListAsync(), c => Assert.True(c.IsVerified));
        Assert.Equal(result, await service.ExtendAsync(request, default));
        Assert.Equal(2, inference.IndexCalls);
    }

    private sealed class FailingOnceInference : IGrpcInferenceService
    {
        public int IndexCalls { get; private set; }
        public Task DeactivateDocumentAsync(string number, CancellationToken ct = default) => Task.CompletedTask;
        public Task<VerificationResultDto> VerifyLegalDocumentAsync(string title, string number, string content, CancellationToken ct = default) =>
            Task.FromResult(new VerificationResultDto { IsValid = true, Status = "Verified" });
        public Task<IndexDocumentResultDto> IndexDocumentAsync(IEnumerable<DocumentChunkInputDto> rows, CancellationToken ct = default)
        {
            IndexCalls++;
            var count = rows.Count();
            return Task.FromResult(new IndexDocumentResultDto { Success = IndexCalls > 1, IndexedCount = IndexCalls > 1 ? count : count - 1 });
        }
        public Task<ChatInferenceResultDto> ProcessTurnAsync(ChatInferenceInputDto input, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<ChatInferenceResultDto> ProcessChatMessageAsync(string user, string session, string prompt, CancellationToken ct = default) =>
            throw new NotSupportedException();
    }

    private sealed class FailingEditionFourInference : IGrpcInferenceService
    {
        public int IndexCalls { get; private set; }
        public int VerifyCalls { get; private set; }
        public int DeactivateCalls { get; private set; }
        public Task DeactivateDocumentAsync(string number, CancellationToken ct = default)
        { DeactivateCalls++; return Task.CompletedTask; }
        public Task<VerificationResultDto> VerifyLegalDocumentAsync(string title, string number, string content, CancellationToken ct = default) =>
            Task.FromResult(new VerificationResultDto { IsValid = true, Status = "Verified" });
        public Task<IndexDocumentResultDto> IndexDocumentAsync(IEnumerable<DocumentChunkInputDto> rows, CancellationToken ct = default)
        {
            IndexCalls++;
            var items = rows.ToArray();
            if (IndexCalls is 1 or 2 or 3 or 5) Assert.All(items, c => Assert.False(c.IsActive));
            else Assert.All(items, c => Assert.True(c.IsActive));
            var success = IndexCalls != 1;
            return Task.FromResult(new IndexDocumentResultDto { Success = success,
                IndexedCount = success ? items.Length : items.Length - 1 });
        }
        public Task<bool> VerifyDocumentIndexAsync(IEnumerable<DocumentChunkInputDto> rows, CancellationToken ct = default)
        {
            VerifyCalls++;
            var expected = rows.ToArray();
            Assert.True(expected.Length > 596);
            Assert.Equal(596, expected.Count(c => int.Parse(c.Article) <= 55));
            if (VerifyCalls <= 2)
            {
                Assert.All(expected.Where(c => int.Parse(c.Article) <= 55), c => Assert.True(c.IsActive));
                Assert.All(expected.Where(c => int.Parse(c.Article) > 55), c => Assert.False(c.IsActive));
            }
            else Assert.All(expected, c => Assert.True(c.IsActive));
            return Task.FromResult(VerifyCalls > 1);
        }
        public Task<ChatInferenceResultDto> ProcessTurnAsync(ChatInferenceInputDto input, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<ChatInferenceResultDto> ProcessChatMessageAsync(string user, string session, string prompt, CancellationToken ct = default) =>
            throw new NotSupportedException();
    }
}
