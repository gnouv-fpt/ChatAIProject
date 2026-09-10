using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using DataAccess.Repositories.Models;
using BusinessObject.Enums;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class DocumentChunkEmbeddingRepository : IDocumentChunkEmbeddingRepository
{
    private readonly ChatAIWebDbContext _context;

    public DocumentChunkEmbeddingRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public async Task AddRangeAsync(
        IEnumerable<DocumentChunkEmbedding> embeddings,
        CancellationToken cancellationToken = default)
    {
        var items = embeddings.ToList();
        if (items.Count == 0)
        {
            return;
        }

        _context.DocumentChunkEmbeddings.AddRange(items);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<DocumentChunkEmbedding>> GetBySubjectAsync(
        int subjectId,
        string embeddingModel,
        CancellationToken cancellationToken = default)
    {
        return await _context.DocumentChunkEmbeddings
            .AsNoTracking()
            .Include(embedding => embedding.DocumentChunk)
            .ThenInclude(chunk => chunk.Document)
            .Where(embedding =>
                embedding.EmbeddingModel == embeddingModel
                && embedding.EmbeddingJson != null
                && embedding.DocumentChunk.Document.SubjectId == subjectId
                && embedding.DocumentChunk.Document.Status == DocumentStatus.Indexed)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<EmbeddingModelTokenUsageAggregate>> GetTokenUsageByModelAsync(
        DateTime startInclusive,
        DateTime endExclusive,
        CancellationToken cancellationToken = default)
    {
        var rows = await _context.DocumentChunkEmbeddings
            .AsNoTracking()
            .Where(embedding =>
                embedding.CreatedAt >= startInclusive
                && embedding.CreatedAt < endExclusive)
            .Select(embedding => new
            {
                embedding.EmbeddingModel,
                TokenCount = embedding.DocumentChunk.TokenCount ?? 0
            })
            .GroupBy(embedding => embedding.EmbeddingModel)
            .Select(group => new
            {
                EmbeddingModel = group.Key,
                TokenCount = group.Sum(embedding => embedding.TokenCount),
                EmbeddingCount = group.Count()
            })
            .OrderByDescending(usage => usage.TokenCount)
            .ThenBy(usage => usage.EmbeddingModel)
            .ToListAsync(cancellationToken);

        return rows
            .Select(row => new EmbeddingModelTokenUsageAggregate(
                row.EmbeddingModel,
                row.TokenCount,
                row.EmbeddingCount))
            .ToList();
    }

    public async Task<IReadOnlyList<DailyEmbeddingModelTokenUsageAggregate>> GetDailyTokenUsageByModelAsync(
        DateTime startInclusive,
        DateTime endExclusive,
        CancellationToken cancellationToken = default)
    {
        var rows = await _context.DocumentChunkEmbeddings
            .AsNoTracking()
            .Where(embedding =>
                embedding.CreatedAt >= startInclusive
                && embedding.CreatedAt < endExclusive)
            .Select(embedding => new
            {
                embedding.CreatedAt,
                embedding.EmbeddingModel,
                TokenCount = embedding.DocumentChunk.TokenCount ?? 0
            })
            .ToListAsync(cancellationToken);

        return rows
            .GroupBy(embedding => new
            {
                UsageDate = embedding.CreatedAt.ToLocalTime().Date,
                embedding.EmbeddingModel
            })
            .Select(group => new DailyEmbeddingModelTokenUsageAggregate(
                group.Key.UsageDate,
                group.Key.EmbeddingModel,
                group.Sum(embedding => embedding.TokenCount)))
            .OrderBy(usage => usage.UsageDate)
            .ThenBy(usage => usage.EmbeddingModel)
            .ToList();
    }

    public async Task<HashSet<int>> GetExistingChunkIdsAsync(
        int subjectId,
        string embeddingModel,
        CancellationToken cancellationToken = default)
    {
        var ids = await _context.DocumentChunkEmbeddings
            .AsNoTracking()
            .Where(embedding =>
                embedding.EmbeddingModel == embeddingModel
                && embedding.DocumentChunk.Document.SubjectId == subjectId
                && embedding.DocumentChunk.Document.Status == DocumentStatus.Indexed)
            .Select(embedding => embedding.DocumentChunkId)
            .ToListAsync(cancellationToken);

        return ids.ToHashSet();
    }
}
