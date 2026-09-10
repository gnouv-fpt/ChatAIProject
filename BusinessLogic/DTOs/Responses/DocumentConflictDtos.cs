namespace BusinessLogic.DTOs.Responses;

public sealed record DocumentConflictAnalysisResult(
    bool HasConflicts,
    int? ReviewId,
    string Message);

public sealed record DocumentConflictReviewDto(
    int Id,
    int SubjectId,
    string SubjectName,
    int NewDocumentId,
    string NewDocumentName,
    string Status,
    string Summary,
    decimal HighestSimilarityScore,
    int FindingCount,
    DateTime CreatedAt,
    string? ResolutionChoice,
    string? ResolvedByName,
    DateTime? ResolvedAt,
    string? ResolutionNote,
    IReadOnlyList<DocumentConflictCandidateDto> Candidates);

public sealed record DocumentConflictCandidateDto(
    int Id,
    int CandidateDocumentId,
    string CandidateDocumentName,
    decimal MaxSimilarityScore,
    int FindingCount,
    string? Summary,
    IReadOnlyList<DocumentConflictFindingDto> Findings);

public sealed record DocumentConflictFindingDto(
    int Id,
    int NewChunkId,
    int ExistingChunkId,
    int NewChunkIndex,
    int ExistingChunkIndex,
    int? NewPageNumber,
    int? ExistingPageNumber,
    int? NewSlideNumber,
    int? ExistingSlideNumber,
    decimal SimilarityScore,
    decimal TextSimilarityScore,
    string Severity,
    string Explanation,
    string NewSnippet,
    string ExistingSnippet);

public sealed record DocumentConflictResolveResult(
    bool Succeeded,
    string Message);
