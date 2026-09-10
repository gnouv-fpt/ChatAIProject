using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

public interface IDocumentConflictService
{
    Task<DocumentConflictAnalysisResult> AnalyzeDocumentAsync(
        int documentId,
        string embeddingModel,
        CancellationToken cancellationToken = default);

    Task<DocumentConflictReviewDto?> GetReviewAsync(
        int reviewId,
        int currentUserId,
        string? currentUserRole,
        CancellationToken cancellationToken = default);

    Task<DocumentConflictReviewDto?> GetPendingReviewByDocumentIdAsync(
        int documentId,
        int currentUserId,
        string? currentUserRole,
        CancellationToken cancellationToken = default);

    Task<DocumentConflictResolveResult> ResolveAsync(
        int reviewId,
        string resolutionChoice,
        int resolvedBy,
        string? resolverRole,
        string? note,
        CancellationToken cancellationToken = default);
}
