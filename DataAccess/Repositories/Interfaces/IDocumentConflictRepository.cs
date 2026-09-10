using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IDocumentConflictRepository
{
    Task AddReviewAsync(DocumentConflictReview review, CancellationToken cancellationToken = default);

    Task<DocumentConflictReview?> GetReviewAsync(int reviewId, CancellationToken cancellationToken = default);

    Task<DocumentConflictReview?> GetPendingReviewByDocumentIdAsync(
        int documentId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyDictionary<int, int>> GetPendingReviewIdsByDocumentIdsAsync(
        IEnumerable<int> documentIds,
        CancellationToken cancellationToken = default);

    Task UpdateReviewAsync(DocumentConflictReview review, CancellationToken cancellationToken = default);
}
