using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class DocumentRepository : GenericRepository<LegalDocument>, IDocumentRepository
{
    public DocumentRepository(ChatAIWebDbContext context)
        : base(context)
    {
    }

    public async Task<DocumentPage> GetDocumentsAsync(
        string? keyword,
        bool? isActive,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(keyword))
        {
            var normalizedKeyword = keyword.Trim();
            query = query.Where(document =>
                document.Title.Contains(normalizedKeyword) ||
                document.DocumentNumber.Contains(normalizedKeyword));
        }

        if (isActive.HasValue)
        {
            query = query.Where(document => document.IsActive == isActive.Value);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderByDescending(document => document.CreatedAt)
            .Skip((pageIndex - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return new DocumentPage { Items = items, TotalCount = totalCount };
    }
}