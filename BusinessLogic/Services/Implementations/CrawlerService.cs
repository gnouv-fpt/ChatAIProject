using BusinessObject.Entities;
using BusinessObject.Enums;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Interfaces;
using HtmlAgilityPack;

namespace BusinessLogic.Services.Implementations;

public sealed class CrawlerService : ICrawlerService
{
    private const string TrafficLawUrl = "https://thuvienphapluat.vn/van-ban/Giao-thong-Van-tai";

    private readonly HttpClient _httpClient;
    private readonly IDocumentRepository _documents;

    public CrawlerService(HttpClient httpClient, IDocumentRepository documents)
    {
        _httpClient = httpClient;
        _documents = documents;
    }

    public async Task CrawlTrafficLawsAsync(CancellationToken cancellationToken = default)
    {
        var response = await _httpClient.GetStringAsync(TrafficLawUrl, cancellationToken);
        var document = new HtmlDocument();
        document.LoadHtml(response);

        var nodes = document.DocumentNode.SelectNodes("//div[contains(@class, 'content-item')]");
        if (nodes is null)
        {
            return;
        }

        foreach (var node in nodes)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var titleNode = node.SelectSingleNode(".//a[@href]");
            var title = HtmlEntity.DeEntitize(titleNode?.InnerText ?? string.Empty).Trim();
            var link = titleNode?.GetAttributeValue("href", string.Empty).Trim();

            if (string.IsNullOrWhiteSpace(title) || string.IsNullOrWhiteSpace(link))
            {
                continue;
            }

            var sourceUrl = new Uri(new Uri(TrafficLawUrl), link).ToString();
            if (await _documents.AnyAsync(document => document.Title == title, cancellationToken))
            {
                continue;
            }

            await _documents.AddAsync(new LegalDocument
            {
                Id = Guid.NewGuid(),
                DocumentNumber = CreateDocumentNumber(sourceUrl),
                Title = title,
                DocumentType = LegalDocumentType.Other,
                SourceUrl = sourceUrl,
                VerificationStatus = VerificationStatus.Pending,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            }, cancellationToken);
        }

        await _documents.SaveChangesAsync(cancellationToken);
    }

    private static string CreateDocumentNumber(string sourceUrl)
    {
        var hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(sourceUrl)))[..16];
        return $"CRAWL-{hash}";
    }
}
