using BusinessObject.Entities;
using DataAccess.Repositories.Models;

namespace DataAccess.Repositories.Interfaces;

public interface IDocumentChunkEmbeddingRepository
{
    Task AddRangeAsync(IEnumerable<DocumentChunkEmbedding> embeddings, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<DocumentChunkEmbedding>> GetBySubjectAsync(
        int subjectId,
        string embeddingModel,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<EmbeddingModelTokenUsageAggregate>> GetTokenUsageByModelAsync(
        DateTime startInclusive,
        DateTime endExclusive,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<DailyEmbeddingModelTokenUsageAggregate>> GetDailyTokenUsageByModelAsync(
        DateTime startInclusive,
        DateTime endExclusive,
        CancellationToken cancellationToken = default);

    Task<HashSet<int>> GetExistingChunkIdsAsync(
        int subjectId,
        string embeddingModel,
        CancellationToken cancellationToken = default);
}
