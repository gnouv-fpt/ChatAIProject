using System.Text.Json;
using System.Text.RegularExpressions;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class DocumentConflictService : IDocumentConflictService
{
    private const double SimilarityThreshold = 0.86;
    private const double NearDuplicateTextThreshold = 0.92;
    private const int MaxFindings = 12;
    private const int MaxFindingsPerCandidate = 5;
    private const int MaxSnippetLength = 520;

    private readonly IDocumentRepository _documentRepository;
    private readonly IDocumentChunkRepository _documentChunkRepository;
    private readonly IDocumentConflictRepository _conflictRepository;
    private readonly ILogger<DocumentConflictService> _logger;

    public DocumentConflictService(
        IDocumentRepository documentRepository,
        IDocumentChunkRepository documentChunkRepository,
        IDocumentConflictRepository conflictRepository,
        ILogger<DocumentConflictService> logger)
    {
        _documentRepository = documentRepository;
        _documentChunkRepository = documentChunkRepository;
        _conflictRepository = conflictRepository;
        _logger = logger;
    }

    public async Task<DocumentConflictAnalysisResult> AnalyzeDocumentAsync(
        int documentId,
        string embeddingModel,
        CancellationToken cancellationToken = default)
    {
        var document = await _documentRepository.GetByIdAsync(documentId, cancellationToken);
        if (document is null)
        {
            return new DocumentConflictAnalysisResult(false, null, "Không tìm thấy tài liệu để kiểm tra sai lệch.");
        }

        var existingReview = await _conflictRepository.GetPendingReviewByDocumentIdAsync(
            documentId,
            cancellationToken);
        if (existingReview is not null)
        {
            return new DocumentConflictAnalysisResult(true, existingReview.Id, "Tài liệu đang chờ kiểm tra sai lệch.");
        }

        var newChunks = document.DocumentChunks
            .Where(chunk => !string.IsNullOrWhiteSpace(chunk.EmbeddingJson))
            .OrderBy(chunk => chunk.ChunkIndex)
            .ToList();
        if (newChunks.Count == 0)
        {
            return new DocumentConflictAnalysisResult(false, null, "Tài liệu không có chunk đủ điều kiện để so sánh.");
        }

        var existingChunks = await _documentChunkRepository.GetIndexedChunksBySubjectAsync(
            document.SubjectId,
            embeddingModel,
            cancellationToken);
        existingChunks = existingChunks
            .Where(chunk => chunk.DocumentId != document.Id)
            .ToList();
        if (existingChunks.Count == 0)
        {
            return new DocumentConflictAnalysisResult(false, null, "Không có tài liệu đã index cùng môn để so sánh.");
        }

        var findings = FindPotentialConflicts(newChunks, existingChunks);
        if (findings.Count == 0)
        {
            return new DocumentConflictAnalysisResult(false, null, "Không phát hiện sai lệch đáng kể với tài liệu đã index.");
        }

        var review = CreateReview(document, findings);
        await _conflictRepository.AddReviewAsync(review, cancellationToken);

        _logger.LogInformation(
            "Created conflict review {ReviewId} for document {DocumentId} with {FindingCount} findings",
            review.Id,
            document.Id,
            findings.Count);

        return new DocumentConflictAnalysisResult(
            true,
            review.Id,
            "Phát hiện nội dung có khả năng trùng/lệch với tài liệu đã có. Tài liệu cần trưởng bộ môn kiểm tra.");
    }

    public async Task<DocumentConflictReviewDto?> GetReviewAsync(
        int reviewId,
        int currentUserId,
        string? currentUserRole,
        CancellationToken cancellationToken = default)
    {
        var review = await _conflictRepository.GetReviewAsync(reviewId, cancellationToken);
        if (review is null || !CanViewReview(review, currentUserId, currentUserRole))
        {
            return null;
        }

        return MapReview(review);
    }

    public async Task<DocumentConflictReviewDto?> GetPendingReviewByDocumentIdAsync(
        int documentId,
        int currentUserId,
        string? currentUserRole,
        CancellationToken cancellationToken = default)
    {
        var review = await _conflictRepository.GetPendingReviewByDocumentIdAsync(
            documentId,
            cancellationToken);
        if (review is null || !CanViewReview(review, currentUserId, currentUserRole))
        {
            return null;
        }

        return MapReview(review);
    }

    public async Task<DocumentConflictResolveResult> ResolveAsync(
        int reviewId,
        string resolutionChoice,
        int resolvedBy,
        string? resolverRole,
        string? note,
        CancellationToken cancellationToken = default)
    {
        var review = await _conflictRepository.GetReviewAsync(reviewId, cancellationToken);
        if (review is null)
        {
            return new DocumentConflictResolveResult(false, "Không tìm thấy báo cáo sai lệch.");
        }

        if (!IsHeadTeacher(review.Subject, resolvedBy, resolverRole))
        {
            return new DocumentConflictResolveResult(false, "Chỉ trưởng bộ môn mới có quyền xử lý sai lệch tài liệu.");
        }

        if (!string.Equals(review.Status, "Pending", StringComparison.OrdinalIgnoreCase))
        {
            return new DocumentConflictResolveResult(false, "Báo cáo này đã được xử lý.");
        }

        var normalizedChoice = NormalizeResolutionChoice(resolutionChoice);
        if (normalizedChoice is null)
        {
            return new DocumentConflictResolveResult(false, "Lựa chọn xử lý sai lệch không hợp lệ.");
        }

        if (normalizedChoice == "AcceptNew")
        {
            await _documentRepository.UpdateStatusAsync(
                review.NewDocumentId,
                DocumentStatus.Indexed,
                indexedAt: review.NewDocument.IndexedAt ?? DateTime.UtcNow,
                cancellationToken: cancellationToken);

            foreach (var documentId in review.Candidates.Select(candidate => candidate.CandidateDocumentId).Distinct())
            {
                await _documentRepository.UpdateStatusAsync(
                    documentId,
                    DocumentStatus.Deleted,
                    "Tài liệu đã bị xóa mềm vì trưởng bộ môn chọn tài liệu mới là bản đúng.",
                    cancellationToken: cancellationToken);
            }
        }
        else if (normalizedChoice == "KeepExisting")
        {
            await _documentRepository.UpdateStatusAsync(
                review.NewDocumentId,
                DocumentStatus.Deleted,
                "Tài liệu đã bị xóa mềm vì trưởng bộ môn giữ tài liệu đã có là bản đúng.",
                cancellationToken: cancellationToken);
        }
        else
        {
            await _documentRepository.UpdateStatusAsync(
                review.NewDocumentId,
                DocumentStatus.Indexed,
                indexedAt: review.NewDocument.IndexedAt ?? DateTime.UtcNow,
                cancellationToken: cancellationToken);
        }

        review.Status = "Resolved";
        review.ResolutionChoice = normalizedChoice;
        review.ResolvedBy = resolvedBy;
        review.ResolvedAt = DateTime.UtcNow;
        review.ResolutionNote = string.IsNullOrWhiteSpace(note) ? null : note.Trim();
        await _conflictRepository.UpdateReviewAsync(review, cancellationToken);

        return new DocumentConflictResolveResult(true, GetResolveMessage(normalizedChoice));
    }

    private static IReadOnlyList<PotentialConflictFinding> FindPotentialConflicts(
        IReadOnlyList<DocumentChunk> newChunks,
        IReadOnlyList<DocumentChunk> existingChunks)
    {
        var existingVectors = existingChunks
            .Select(chunk => new
            {
                Chunk = chunk,
                Vector = DeserializeEmbedding(chunk.EmbeddingJson)
            })
            .Where(item => item.Vector.Length > 0)
            .ToList();

        var findings = new List<PotentialConflictFinding>();
        foreach (var newChunk in newChunks)
        {
            var newVector = DeserializeEmbedding(newChunk.EmbeddingJson);
            if (newVector.Length == 0)
            {
                continue;
            }

            var bestMatches = existingVectors
                .Select(item => new
                {
                    item.Chunk,
                    Similarity = CosineSimilarity(newVector, item.Vector),
                    TextSimilarity = TextSimilarity(newChunk.Content, item.Chunk.Content)
                })
                .Where(item =>
                    item.Similarity >= SimilarityThreshold
                    && item.TextSimilarity < NearDuplicateTextThreshold)
                .OrderByDescending(item => item.Similarity)
                .Take(2);

            foreach (var match in bestMatches)
            {
                findings.Add(new PotentialConflictFinding(
                    newChunk,
                    match.Chunk,
                    Math.Round((decimal)match.Similarity, 6),
                    Math.Round((decimal)match.TextSimilarity, 6),
                    GetSeverity(match.Similarity, match.TextSimilarity),
                    CreateExplanation(newChunk, match.Chunk, match.Similarity, match.TextSimilarity)));
            }
        }

        return findings
            .GroupBy(item => new { NewChunkId = item.NewChunk.Id, ExistingChunkId = item.ExistingChunk.Id })
            .Select(group => group.OrderByDescending(item => item.SimilarityScore).First())
            .OrderByDescending(item => item.SimilarityScore)
            .Aggregate(new List<PotentialConflictFinding>(), (selected, finding) =>
            {
                if (!HasMirroredFinding(selected, finding))
                {
                    selected.Add(finding);
                }

                return selected;
            })
            .Take(MaxFindings)
            .ToList();
    }

    private static DocumentConflictReview CreateReview(
        Document document,
        IReadOnlyList<PotentialConflictFinding> findings)
    {
        var candidates = findings
            .GroupBy(finding => finding.ExistingChunk.DocumentId)
            .Select(group =>
            {
                var orderedFindings = group
                    .OrderByDescending(finding => finding.SimilarityScore)
                    .Take(MaxFindingsPerCandidate)
                    .ToList();
                var candidateDocument = orderedFindings.First().ExistingChunk.Document;

                return new DocumentConflictCandidate
                {
                    CandidateDocumentId = candidateDocument.Id,
                    MaxSimilarityScore = orderedFindings.Max(finding => finding.SimilarityScore),
                    FindingCount = orderedFindings.Count,
                    Summary = $"Phát hiện {orderedFindings.Count} đoạn có nội dung gần giống nhưng diễn đạt khác với {candidateDocument.OriginalFileName}.",
                    CreatedAt = DateTime.UtcNow,
                    Findings = orderedFindings.Select(finding => new DocumentConflictFinding
                    {
                        NewChunkId = finding.NewChunk.Id,
                        ExistingChunkId = finding.ExistingChunk.Id,
                        SimilarityScore = finding.SimilarityScore,
                        TextSimilarityScore = finding.TextSimilarityScore,
                        Severity = finding.Severity,
                        Explanation = finding.Explanation,
                        NewSnippet = CreateSnippet(finding.NewChunk.Content),
                        ExistingSnippet = CreateSnippet(finding.ExistingChunk.Content),
                        CreatedAt = DateTime.UtcNow
                    }).ToList()
                };
            })
            .OrderByDescending(candidate => candidate.MaxSimilarityScore)
            .ToList();
        var savedFindingCount = candidates.Sum(candidate => candidate.FindingCount);
        var highestSimilarityScore = candidates
            .Select(candidate => candidate.MaxSimilarityScore)
            .DefaultIfEmpty(0)
            .Max();

        return new DocumentConflictReview
        {
            SubjectId = document.SubjectId,
            NewDocumentId = document.Id,
            Status = "Pending",
            Summary = $"Phát hiện {savedFindingCount} điểm cần trưởng bộ môn kiểm tra trước khi đưa tài liệu vào RAG.",
            HighestSimilarityScore = highestSimilarityScore,
            FindingCount = savedFindingCount,
            CreatedAt = DateTime.UtcNow,
            Candidates = candidates
        };
    }

    private static DocumentConflictReviewDto MapReview(DocumentConflictReview review)
    {
        var candidateDtos = review.Candidates
            .OrderByDescending(candidate => candidate.MaxSimilarityScore)
            .Select(candidate =>
            {
                var uniqueFindings = candidate.Findings
                    .OrderByDescending(finding => finding.SimilarityScore)
                    .Aggregate(new List<DocumentConflictFinding>(), (selected, finding) =>
                    {
                        if (!HasMirroredStoredFinding(selected, finding))
                        {
                            selected.Add(finding);
                        }

                        return selected;
                    });
                var findingDtos = uniqueFindings
                    .Select(finding => new DocumentConflictFindingDto(
                        finding.Id,
                        finding.NewChunkId,
                        finding.ExistingChunkId,
                        finding.NewChunk.ChunkIndex,
                        finding.ExistingChunk.ChunkIndex,
                        finding.NewChunk.PageNumber,
                        finding.ExistingChunk.PageNumber,
                        finding.NewChunk.SlideNumber,
                        finding.ExistingChunk.SlideNumber,
                        finding.SimilarityScore,
                        finding.TextSimilarityScore,
                        finding.Severity,
                        finding.Explanation,
                        finding.NewSnippet,
                        finding.ExistingSnippet))
                    .ToList();

                var candidateFindingCount = findingDtos.Count;
                var candidateMaxSimilarity = findingDtos.Count == 0
                    ? candidate.MaxSimilarityScore
                    : findingDtos.Max(finding => finding.SimilarityScore);
                var candidateSummary = $"Phát hiện {candidateFindingCount} đoạn có nội dung gần giống nhưng diễn đạt khác với {candidate.CandidateDocument.OriginalFileName}.";

                return new DocumentConflictCandidateDto(
                    candidate.Id,
                    candidate.CandidateDocumentId,
                    candidate.CandidateDocument.OriginalFileName,
                    candidateMaxSimilarity,
                    candidateFindingCount,
                    candidateSummary,
                    findingDtos);
            })
            .ToList();
        var findingCount = candidateDtos.Sum(candidate => candidate.FindingCount);
        var highestSimilarity = candidateDtos
            .SelectMany(candidate => candidate.Findings)
            .Select(finding => finding.SimilarityScore)
            .DefaultIfEmpty(review.HighestSimilarityScore)
            .Max();
        var summary = $"Phát hiện {findingCount} điểm cần trưởng bộ môn kiểm tra trước khi đưa tài liệu vào RAG.";

        return new DocumentConflictReviewDto(
            review.Id,
            review.SubjectId,
            string.IsNullOrWhiteSpace(review.Subject.SubjectCode)
                ? review.Subject.SubjectName
                : $"{review.Subject.SubjectCode} - {review.Subject.SubjectName}",
            review.NewDocumentId,
            review.NewDocument.OriginalFileName,
            review.Status,
            summary,
            highestSimilarity,
            findingCount,
            review.CreatedAt,
            review.ResolutionChoice,
            review.ResolvedByNavigation?.FullName,
            review.ResolvedAt,
            review.ResolutionNote,
            candidateDtos);
    }

    private static bool CanViewReview(
        DocumentConflictReview review,
        int userId,
        string? userRole)
    {
        return string.Equals(userRole, UserRoleNames.Admin, StringComparison.OrdinalIgnoreCase)
            || IsHeadTeacher(review.Subject, userId, userRole);
    }

    private static bool IsHeadTeacher(
        Subject subject,
        int userId,
        string? userRole)
    {
        return string.Equals(userRole, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase)
            && subject.CreatedBy == userId;
    }

    private static string? NormalizeResolutionChoice(string choice)
    {
        if (string.Equals(choice, "AcceptNew", StringComparison.OrdinalIgnoreCase))
        {
            return "AcceptNew";
        }

        if (string.Equals(choice, "KeepExisting", StringComparison.OrdinalIgnoreCase))
        {
            return "KeepExisting";
        }

        if (string.Equals(choice, "NoConflict", StringComparison.OrdinalIgnoreCase))
        {
            return "NoConflict";
        }

        return null;
    }

    private static string GetResolveMessage(string choice)
    {
        return choice switch
        {
            "AcceptNew" => "Đã chọn tài liệu mới là bản đúng và xóa mềm các tài liệu cũ bị mâu thuẫn.",
            "KeepExisting" => "Đã giữ tài liệu cũ là bản đúng và xóa mềm tài liệu mới.",
            _ => "Đã xác nhận không có xung đột và đưa tài liệu vào kho RAG."
        };
    }

    private static string GetSeverity(double similarity, double textSimilarity)
    {
        if (similarity >= 0.94 && textSimilarity <= 0.65)
        {
            return "High";
        }

        if (similarity >= 0.9)
        {
            return "Medium";
        }

        return "Low";
    }

    private static string CreateExplanation(
        DocumentChunk newChunk,
        DocumentChunk existingChunk,
        double similarity,
        double textSimilarity)
    {
        var location = FormatLocation(newChunk.PageNumber, newChunk.SlideNumber);
        var existingLocation = FormatLocation(existingChunk.PageNumber, existingChunk.SlideNumber);
        return $"AI phát hiện chunk {newChunk.ChunkIndex} {location} có cùng chủ đề với chunk {existingChunk.ChunkIndex} {existingLocation} nhưng nội dung diễn đạt khác đáng kể. Cần trưởng bộ môn đối chiếu để chọn nguồn đúng.";
    }

    private static bool HasMirroredFinding(
        IReadOnlyList<PotentialConflictFinding> selected,
        PotentialConflictFinding candidate)
    {
        return selected.Any(item =>
            item.ExistingChunk.DocumentId == candidate.ExistingChunk.DocumentId
            && Math.Min(item.NewChunk.ChunkIndex, item.ExistingChunk.ChunkIndex)
                == Math.Min(candidate.NewChunk.ChunkIndex, candidate.ExistingChunk.ChunkIndex)
            && Math.Max(item.NewChunk.ChunkIndex, item.ExistingChunk.ChunkIndex)
                == Math.Max(candidate.NewChunk.ChunkIndex, candidate.ExistingChunk.ChunkIndex));
    }

    private static bool HasMirroredStoredFinding(
        IReadOnlyList<DocumentConflictFinding> selected,
        DocumentConflictFinding candidate)
    {
        return selected.Any(item =>
            Math.Min(item.NewChunk.ChunkIndex, item.ExistingChunk.ChunkIndex)
                == Math.Min(candidate.NewChunk.ChunkIndex, candidate.ExistingChunk.ChunkIndex)
            && Math.Max(item.NewChunk.ChunkIndex, item.ExistingChunk.ChunkIndex)
                == Math.Max(candidate.NewChunk.ChunkIndex, candidate.ExistingChunk.ChunkIndex));
    }

    private static string FormatLocation(int? pageNumber, int? slideNumber)
    {
        if (pageNumber.HasValue)
        {
            return $"trang {pageNumber.Value}";
        }

        if (slideNumber.HasValue)
        {
            return $"slide {slideNumber.Value}";
        }

        return "không có số trang/slide";
    }

    private static string CreateSnippet(string content)
    {
        var normalized = string.Join(' ', content.Split(default(string[]), StringSplitOptions.RemoveEmptyEntries));
        return normalized.Length <= MaxSnippetLength
            ? normalized
            : $"{normalized[..MaxSnippetLength]}...";
    }

    private static float[] DeserializeEmbedding(string? embeddingJson)
    {
        if (string.IsNullOrWhiteSpace(embeddingJson))
        {
            return [];
        }

        try
        {
            return JsonSerializer.Deserialize<float[]>(embeddingJson) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    private static double CosineSimilarity(IReadOnlyList<float> left, IReadOnlyList<float> right)
    {
        var length = Math.Min(left.Count, right.Count);
        if (length == 0)
        {
            return 0;
        }

        double dot = 0;
        double leftMagnitude = 0;
        double rightMagnitude = 0;
        for (var index = 0; index < length; index++)
        {
            dot += left[index] * right[index];
            leftMagnitude += left[index] * left[index];
            rightMagnitude += right[index] * right[index];
        }

        return leftMagnitude == 0 || rightMagnitude == 0
            ? 0
            : dot / (Math.Sqrt(leftMagnitude) * Math.Sqrt(rightMagnitude));
    }

    private static double TextSimilarity(string left, string right)
    {
        var leftTerms = Tokenize(left);
        var rightTerms = Tokenize(right);
        if (leftTerms.Count == 0 || rightTerms.Count == 0)
        {
            return 0;
        }

        var intersection = leftTerms.Intersect(rightTerms).Count();
        var union = leftTerms.Union(rightTerms).Count();
        return union == 0 ? 0 : intersection / (double)union;
    }

    private static HashSet<string> Tokenize(string value)
    {
        var normalized = Regex.Replace(value.ToLowerInvariant(), @"[^\p{L}\p{Nd}\s]+", " ");
        return normalized
            .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(term => term.Length > 2)
            .ToHashSet();
    }

    private sealed record PotentialConflictFinding(
        DocumentChunk NewChunk,
        DocumentChunk ExistingChunk,
        decimal SimilarityScore,
        decimal TextSimilarityScore,
        string Severity,
        string Explanation);
}
