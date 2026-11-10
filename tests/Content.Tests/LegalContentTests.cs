using BusinessLogic.Exceptions;
using BusinessLogic.Services.Implementations;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess;
using DataAccess.Repositories.Implementations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Content.Tests;

public sealed class LegalContentTests
{
    [Theory]
    [InlineData("https://thuvienphapluat.vn/van-ban/test.aspx", true)]
    [InlineData("https://thuvienphapluat.vn.evil.org/van-ban/test.aspx", false)]
    [InlineData("http://thuvienphapluat.vn/van-ban/test.aspx", false)]
    [InlineData("https://user:password@thuvienphapluat.vn/van-ban/test.aspx", false)]
    [InlineData("https://datafiles.chinhphu.vn/cpp/files/vbpq/2024/11/51-bgtvt-kem.pdf", true)]
    [InlineData("https://datafiles.chinhphu.vn/cpp/files/vbpq/2024/11/other.pdf", false)]
    public void SourceIsRestricted(string source, bool expected) => Assert.Equal(expected, LegalContentParser.IsAllowedSource(new(source)));

    [Fact]
    public void ParserRequiresRealNumberAndTextAndKeepsArticleClause()
    {
        var html = "<h1>Văn bản kiểm thử</h1><table><tr><td>Số: 01/2026/TEST</td></tr></table>" +
            "<div id='divContentDoc'><p>Điều 1. Phạm vi kiểm thử</p><p>1. " + new string('x', 120) + "</p><p>Điều 2. Nội dung tiếp</p><p>1. Tiếp theo</p></div>";
        var parsed = LegalContentParser.Parse(html);
        Assert.Equal("01/2026/TEST", parsed.Number);
        var chunks = LegalContentParser.Chunk(parsed.Content);
        Assert.Contains(chunks, c => c.Article == "1" && c.Clause == "1");
        Assert.Contains(chunks, c => c.Article == "2" && c.Clause == "1");
        Assert.Throws<BadRequestException>(() => LegalContentParser.Parse("<h1>Access denied</h1>"));
    }

    [Fact]
    public void ChunkKeepsAmendedClauseAndPointIdentifiers()
    {
        const string content = "Điều 32. Xử phạt chủ phương tiện\n9. Nội dung cũ\n9a. Mức phạt mới\n" +
            "a) Hành vi thứ nhất\nb) Hành vi thứ hai\nĐiều 41. Thẩm quyền\n4. Danh mục\n" +
            "k) Điểm cũ\nk1) Điểm mới";
        var chunks = LegalContentParser.Chunk(content);
        Assert.Contains(chunks, c => c.Article == "32" && c.Clause == "9a" && c.Point == "a");
        Assert.Contains(chunks, c => c.Article == "32" && c.Clause == "9a" && c.Point == "b");
        Assert.Contains(chunks, c => c.Article == "41" && c.Clause == "4" && c.Point == "k1");
        Assert.DoesNotContain(chunks, c => c.Clause == "9" && c.Content.Contains("Mức phạt mới"));
    }

    [Fact]
    public void ChunkKeepsQcvnAppendixSectionAndPoint()
    {
        const string text = "Phụ lục B. Ý nghĩa biển cấm\nB.1 Biển số P.101 Đường cấm\n" +
            "a) Cấm hai hướng\nB.2 Biển số P.102 Cấm đi ngược chiều\na) Cấm chiều đặt biển";
        var chunks = LegalContentParser.Chunk(text);
        Assert.Contains(chunks, c => c.Article == "Phụ lục B" && c.Clause == "B.1" && c.Point == "a");
        Assert.Contains(chunks, c => c.Article == "Phụ lục B" && c.Clause == "B.2" && c.Point == "a");
        Assert.Equal(5, chunks.Count);
    }

    [Fact]
    public async Task ExpiryIsIdempotentAndPreservesChatHistory()
    {
        await using var db = new ContentDbContext(new DbContextOptionsBuilder<ContentDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        var id = Guid.NewGuid();
        db.LegalDocuments.Add(new() { Id = id, DocumentNumber = "test", Title = "test", IsActive = true,
            VerificationStatus = VerificationStatus.Verified, ExpirationDate = DateTime.UtcNow.AddDays(-1) });
        db.DocumentChunks.Add(new() { Id = Guid.NewGuid(), DocumentId = id, Content = "test", IsVerified = true });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var service = new ContentMaintenanceService(new DocumentRepository(db), new GenericRepository<DocumentChunk>(db),
            NullLogger<ContentMaintenanceService>.Instance);
        Assert.Equal(1, (await service.RunAsync()).ExpiredDocuments);
        db.ChangeTracker.Clear();
        Assert.Equal(0, (await service.RunAsync()).ExpiredDocuments);
        Assert.False((await db.DocumentChunks.SingleAsync()).IsVerified);
        Assert.False((await db.LegalDocuments.SingleAsync()).IsActive);
    }
}
