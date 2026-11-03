using System.Security.Cryptography;
using System.Text;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Implementations;
using DataAccess;
using DataAccess.Repositories.Implementations;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Content.Tests;

public sealed class LegalCorpusTests
{
    [Fact]
    public async Task ReviewedCaptureIsPendingIdempotentAndRejectsChangedHashOrScope()
    {
        await using var db = new ContentDbContext(new DbContextOptionsBuilder<ContentDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var service = new LegalCorpusService(null!, new DocumentRepository(db),
            new GenericRepository<BusinessObject.Entities.DocumentChunk>(db));
        const string content = "Điều 11. Nội dung kiểm thử\n1. " +
            "Đây là nội dung tổng hợp dành riêng cho kiểm thử, không được coi là căn cứ pháp lý hoặc dữ liệu để demo.\n" +
            "a) Phương án thử thứ nhất.\nb) Phương án thử thứ hai.";
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(content)));
        var request = new ImportCapturedLegalCorpusRequest("https://thuvienphapluat.vn/van-ban/test.aspx", "TEST/CORPUS", "TEST FIXTURE",
            content, hash, ["11"], "https://datafiles.chinhphu.vn/test.pdf", "Synthetic test only; never activate.");
        var imported = await service.ImportCapturedAsync(request, default);
        var saved = await db.LegalDocuments.SingleAsync();
        Assert.False(saved.IsActive);
        Assert.Equal(BusinessObject.Enums.VerificationStatus.Pending, saved.VerificationStatus);
        Assert.All(await db.DocumentChunks.ToListAsync(), chunk => Assert.False(chunk.IsVerified));
        var ids = await db.DocumentChunks.Select(c => c.Id).ToArrayAsync();
        Assert.Equal(imported, await service.ImportCapturedAsync(request, default));
        Assert.Equal(ids, await db.DocumentChunks.Select(c => c.Id).ToArrayAsync());
        await Assert.ThrowsAsync<ConflictException>(() => service.ImportCapturedAsync(request with { ContentSha256 = new string('0',64) }, default));
        await Assert.ThrowsAsync<BadRequestException>(() => service.ImportCapturedAsync(request with { Articles = ["12"] }, default));
        await Assert.ThrowsAsync<BadRequestException>(() => service.ImportCapturedAsync(request with { SourceUrl = "https://evil.example/van-ban/test.aspx" }, default));
        Assert.Single(await db.LegalDocuments.ToListAsync());
    }
}
