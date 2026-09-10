using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class DocumentConflictRepository : IDocumentConflictRepository
{
    private readonly ChatAIWebDbContext _context;

    public DocumentConflictRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public async Task AddReviewAsync(
        DocumentConflictReview review,
        CancellationToken cancellationToken = default)
    {
        _context.DocumentConflictReviews.Add(review);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public Task<DocumentConflictReview?> GetReviewAsync(
        int reviewId,
        CancellationToken cancellationToken = default)
    {
        return CreateReviewQuery()
            .FirstOrDefaultAsync(review => review.Id == reviewId, cancellationToken);
    }

    public Task<DocumentConflictReview?> GetPendingReviewByDocumentIdAsync(
        int documentId,
        CancellationToken cancellationToken = default)
    {
        return CreateReviewQuery()
            .Where(review => review.NewDocumentId == documentId && review.Status == "Pending")
            .OrderByDescending(review => review.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<IReadOnlyDictionary<int, int>> GetPendingReviewIdsByDocumentIdsAsync(
        IEnumerable<int> documentIds,
        CancellationToken cancellationToken = default)
    {
        var ids = documentIds.ToHashSet();
        if (ids.Count == 0)
        {
            return new Dictionary<int, int>();
        }

        var reviews = await _context.DocumentConflictReviews
            .AsNoTracking()
            .Where(review => ids.Contains(review.NewDocumentId) && review.Status == "Pending")
            .GroupBy(review => review.NewDocumentId)
            .Select(group => new
            {
                DocumentId = group.Key,
                ReviewId = group
                    .OrderByDescending(review => review.CreatedAt)
                    .Select(review => review.Id)
                    .First()
            })
            .ToListAsync(cancellationToken);

        return reviews.ToDictionary(item => item.DocumentId, item => item.ReviewId);
    }

    public async Task UpdateReviewAsync(
        DocumentConflictReview review,
        CancellationToken cancellationToken = default)
    {
        await _context.SaveChangesAsync(cancellationToken);
    }

    private IQueryable<DocumentConflictReview> CreateReviewQuery()
    {
        return _context.DocumentConflictReviews
            .Include(review => review.Subject)
                .ThenInclude(subject => subject.SubjectEnrollments)
            .Include(review => review.NewDocument)
                .ThenInclude(document => document.DocumentChunks)
            .Include(review => review.NewDocument)
                .ThenInclude(document => document.UploadedByNavigation)
            .Include(review => review.ResolvedByNavigation)
            .Include(review => review.Candidates)
                .ThenInclude(candidate => candidate.CandidateDocument)
            .Include(review => review.Candidates)
                .ThenInclude(candidate => candidate.Findings)
                    .ThenInclude(finding => finding.NewChunk)
            .Include(review => review.Candidates)
                .ThenInclude(candidate => candidate.Findings)
                    .ThenInclude(finding => finding.ExistingChunk)
            .AsSplitQuery();
    }
}
