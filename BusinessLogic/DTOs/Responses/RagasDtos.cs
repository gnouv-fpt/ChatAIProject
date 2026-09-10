namespace BusinessLogic.DTOs.Responses;

public sealed record EvaluationQuestionDto(
    int Id,
    int SubjectId,
    string SubjectName,
    string Question,
    string GroundTruthAnswer,
    bool IsAnswerable,
    bool IsBenchmarkReady,
    int GoldChunkCount,
    string? CreatedByName,
    DateTime CreatedAt);

public sealed record EvaluationQuestionSetupDto(
    int Id,
    int SubjectId,
    string SubjectName,
    string Question,
    string GroundTruthAnswer,
    bool IsAnswerable,
    bool IsBenchmarkReady,
    IReadOnlyList<EvaluationQuestionGoldChunkDto> GoldChunks);

public sealed record EvaluationQuestionGoldChunkDto(
    int ChunkId,
    int DocumentId,
    string DocumentTitle,
    string OriginalFileName,
    int ChunkIndex,
    int? PageNumber,
    int? SlideNumber,
    string Content,
    byte RelevanceGrade);

public sealed record BenchmarkChunkCandidateDto(
    int ChunkId,
    int DocumentId,
    string DocumentTitle,
    string OriginalFileName,
    int ChunkIndex,
    int? PageNumber,
    int? SlideNumber,
    string Content,
    decimal SuggestionScore,
    bool IsSelected,
    byte? RelevanceGrade);

public sealed record CreateEvaluationQuestionResult(
    bool Success,
    string Message,
    int? QuestionId = null);

public sealed record BenchmarkReadinessDto(
    bool IsReady,
    int TotalQuestions,
    int ReadyQuestions,
    int AnswerableQuestions,
    int UnanswerableQuestions,
    IReadOnlyList<string> Errors);

public sealed record RagasBenchmarkResultDto(
    int Id,
    int EvaluationQuestionId,
    string RunId,
    string Question,
    string? GroundTruthAnswer,
    bool IsAnswerable,
    string EmbeddingModel,
    string? LlmModel,
    string? VectorStore,
    string ChunkingStrategy,
    string? GeneratedAnswer,
    string? RetrievedContextsJson,
    IReadOnlyList<int> RetrievedChunkIds,
    IReadOnlyList<int> CitationChunkIds,
    decimal? RecallAt5,
    decimal? MrrAt10,
    decimal? NdcgAt5,
    decimal? AnswerCorrectness,
    decimal? Faithfulness,
    decimal? CitationPrecision,
    decimal? CitationRecall,
    decimal? CitationF1,
    bool ExpectedNoAnswer,
    bool PredictedNoAnswer,
    long EmbeddingLatencyMs,
    long RetrievalLatencyMs,
    long GenerationLatencyMs,
    long EndToEndLatencyMs,
    DateTime CreatedAt);

public sealed record RagasRunSummaryDto(
    int SubjectId,
    string SubjectName,
    string RunId,
    string EmbeddingModel,
    string? LlmModel,
    string ChunkingStrategy,
    int QuestionCount,
    decimal AvgRecallAt5,
    decimal AvgMrrAt10,
    decimal AvgNdcgAt5,
    decimal AvgAnswerCorrectness,
    decimal AvgFaithfulness,
    decimal AvgCitationF1,
    decimal? NoAnswerF1,
    long EndToEndLatencyP50Ms,
    long EndToEndLatencyP95Ms,
    DateTime RunDate,
    IReadOnlyList<RagasModelSummaryDto> ModelSummaries,
    IReadOnlyList<RagasTokenUsageSummaryDto> WeeklyTokenUsage,
    IReadOnlyList<RagasBenchmarkResultDto> Results);

public sealed record RagasRunHistoryDto(
    int SubjectId,
    string SubjectName,
    int PageNumber,
    int PageSize,
    int TotalRuns,
    IReadOnlyList<RagasRunHistoryItemDto> Items);

public sealed record RagasRunHistoryItemDto(
    string RunId,
    DateTime RunDate,
    IReadOnlyList<string> EmbeddingModels,
    IReadOnlyList<string> ChunkingStrategies,
    int QuestionCount,
    decimal AvgRecallAt5);

public sealed record RagasModelSummaryDto(
    string EmbeddingModel,
    string? LlmModel,
    string? VectorStore,
    string ChunkingStrategy,
    int QuestionCount,
    decimal AvgRecallAt5,
    decimal AvgMrrAt10,
    decimal AvgNdcgAt5,
    decimal AvgAnswerCorrectness,
    decimal AvgFaithfulness,
    decimal AvgCitationF1,
    decimal? NoAnswerF1,
    long EmbeddingLatencyP50Ms,
    long EmbeddingLatencyP95Ms,
    long RetrievalLatencyP50Ms,
    long RetrievalLatencyP95Ms,
    long EndToEndLatencyP50Ms,
    long EndToEndLatencyP95Ms);

public sealed record RagasTokenUsageSummaryDto(
    string EmbeddingModel,
    string? LlmModel,
    int RunCount,
    int QuestionCount,
    int EstimatedEmbeddingTokens,
    int EstimatedPromptTokens,
    int EstimatedCompletionTokens,
    int EstimatedTotalTokens,
    decimal AvgRecallAt5,
    DateTime FromUtc,
    DateTime ToUtc);

public sealed record BenchmarkChunkingStrategyDto(
    string Key,
    string DisplayName,
    string Description,
    bool IsDefault);

public sealed record SubjectEvaluationSummaryDto(
    int SubjectId,
    string SubjectCode,
    string SubjectName,
    int QuestionCount,
    int BenchmarkRunCount,
    decimal? LastRecallAt5,
    DateTime? LastRunDate);