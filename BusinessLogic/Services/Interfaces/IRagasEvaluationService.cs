using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

public interface IRagasEvaluationService
{
    Task<IReadOnlyList<SubjectEvaluationSummaryDto>> GetSubjectSummariesAsync(
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<EvaluationQuestionDto>> GetQuestionsAsync(
        int subjectId,
        CancellationToken cancellationToken = default);

    Task<EvaluationQuestionSetupDto?> GetQuestionSetupAsync(
        int questionId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<BenchmarkChunkCandidateDto>> SuggestGoldChunksAsync(
        int questionId,
        string? searchTerm = null,
        CancellationToken cancellationToken = default);

    Task<OperationResult> SaveQuestionBenchmarkSetupAsync(
        SaveQuestionBenchmarkSetupRequest request,
        CancellationToken cancellationToken = default);

    Task<BenchmarkReadinessDto> GetBenchmarkReadinessAsync(
        int subjectId,
        CancellationToken cancellationToken = default);

    IReadOnlyList<BenchmarkChunkingStrategyDto> GetChunkingStrategies();

    Task<CreateEvaluationQuestionResult> AddQuestionAsync(
        int subjectId,
        string question,
        string groundTruthAnswer,
        int createdBy,
        CancellationToken cancellationToken = default);

    Task<OperationResult> UpdateQuestionAsync(
        int id,
        string question,
        string groundTruthAnswer,
        CancellationToken cancellationToken = default);

    Task<OperationResult> DeleteQuestionAsync(
        int id,
        CancellationToken cancellationToken = default);

    Task<OperationResult> SeedQuestionsAsync(
        int subjectId,
        int createdBy,
        CancellationToken cancellationToken = default);

    Task<RagasRunSummaryDto?> RunEvaluationAsync(
        int subjectId,
        IReadOnlyList<string>? embeddingModels = null,
        IReadOnlyList<string>? chunkingStrategies = null,
        RagasEvaluationProgressContext? progressContext = null,
        CancellationToken cancellationToken = default);

    Task<RagasRunSummaryDto?> GetLatestRunAsync(
        int subjectId,
        CancellationToken cancellationToken = default);

    Task<RagasRunSummaryDto?> GetRunAsync(
        int subjectId,
        string runId,
        CancellationToken cancellationToken = default);

    Task<RagasRunHistoryDto?> GetRunHistoryAsync(
        int subjectId,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default);
}