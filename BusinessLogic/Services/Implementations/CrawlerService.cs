using BusinessObject.Entities;
using BusinessObject.Enums;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Interfaces;
using HtmlAgilityPack;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class CrawlerService(HttpClient httpClient, IDocumentRepository documents,
    IGenericRepository<DocumentChunk> chunks, ILogger<CrawlerService> logger) : ICrawlerService
{
    private static readonly Uri Listing = new("https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai");
    public async Task CrawlTrafficLawsAsync(CancellationToken cancellationToken = default)
    {
        var doc = new HtmlDocument();
        doc.LoadHtml(await GetHtmlAsync(Listing, cancellationToken));
        var links = doc.DocumentNode.SelectNodes("//a[@href]")?
            .Select(n => Uri.TryCreate(Listing, n.GetAttributeValue("href", ""), out var uri) ? uri : null)
            .Where(u => u is not null && LegalContentParser.IsAllowedSource(u) && u.AbsolutePath.EndsWith(".aspx", StringComparison.OrdinalIgnoreCase))
            .Cast<Uri>().DistinctBy(u => u.AbsolutePath).Take(50).ToList() ?? [];
        if (links.Count == 0) throw new BadRequestException("Không tìm thấy link văn bản; cần kiểm tra selector hoặc nguồn đang chặn truy cập.");
        var added = 0;
        foreach (var uri in links)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (await documents.AnyAsync(d => d.SourceUrl == uri.AbsoluteUri, cancellationToken)) continue;
            var parsed = LegalContentParser.Parse(await GetHtmlAsync(uri, cancellationToken));
            if (await documents.AnyAsync(d => d.DocumentNumber == parsed.Number, cancellationToken)) continue;
            var document = new LegalDocument { Id = Guid.NewGuid(), DocumentNumber = parsed.Number,
                Title = parsed.Title, SourceUrl = uri.AbsoluteUri, CreatedAt = DateTime.UtcNow,
                VerificationStatus = VerificationStatus.Pending, IsActive = false, DocumentType = LegalDocumentType.Other };
            if (parsed.Title.Length > 500) throw new BadRequestException("Tiêu đề nguồn vượt giới hạn lưu trữ.");
            var contentChunks = LegalContentParser.Chunk(parsed.Content);
            if (contentChunks.Count == 0) throw new BadRequestException("Không tách được Điều luật từ nguồn.");
            await documents.AddAsync(document, cancellationToken);
            foreach (var chunk in contentChunks)
                await chunks.AddAsync(new DocumentChunk { Id = Guid.NewGuid(), DocumentId = document.Id,
                    Article = chunk.Article, Clause = chunk.Clause, Content = chunk.Content,
                    IsVerified = false, TokenCount = 0 }, cancellationToken);
            await documents.SaveChangesAsync(cancellationToken);
            added++;
        }
        logger.LogInformation("Legal crawl completed: discovered {Discovered}, added {Added}", links.Count, added);
    }
    private async Task<string> GetHtmlAsync(Uri uri, CancellationToken cancellationToken)
    {
        if (!LegalContentParser.IsAllowedSource(uri)) throw new BadRequestException("Chỉ chấp nhận nguồn thuvienphapluat.vn qua HTTPS.");
        using var response = await httpClient.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();
        if (response.RequestMessage?.RequestUri is not Uri final || !LegalContentParser.IsAllowedSource(final))
            throw new BadRequestException("Nguồn chuyển hướng ra ngoài phạm vi cho phép.");
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var buffer = new MemoryStream();
        var bytes = new byte[8192];
        int count;
        while ((count = await stream.ReadAsync(bytes, cancellationToken)) > 0)
        {
            if (buffer.Length + count > 8 * 1024 * 1024) throw new BadRequestException("Nội dung nguồn vượt 8 MB.");
            await buffer.WriteAsync(bytes.AsMemory(0, count), cancellationToken);
        }
        return System.Text.Encoding.UTF8.GetString(buffer.ToArray());
    }
}
