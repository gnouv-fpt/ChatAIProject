using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public sealed class DocumentPage
{
    public List<LegalDocument> Items { get; init; } = new();
    public int TotalCount { get; init; }
}

public interface IDocumentRepository : IGenericRepository<LegalDocument>
{
    Task<DocumentPage> GetDocumentsAsync(
        string? keyword,
        bool? isActive,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default);
}