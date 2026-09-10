using System.ComponentModel.DataAnnotations;

namespace Presentation.Models;

public sealed class RagasSubjectListViewModel
{
    public List<RagasSubjectItem> Subjects { get; set; } = new();
}

public sealed class RagasSubjectItem
{
    public int SubjectId { get; set; }
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectName { get; set; } = string.Empty;
    public int QuestionCount { get; set; }
    public int BenchmarkRunCount { get; set; }
    public decimal? LastRecallAt5 { get; set; }
    public DateTime? LastRunDate { get; set; }
}

public sealed class RagasQuestionsViewModel
{
    public int SubjectId { get; set; }
    public string SubjectName { get; set; } = string.Empty;
    public List<RagasEmbeddingModelOption> EmbeddingModels { get; set; } = new();
    public List<RagasChunkingStrategyOption> ChunkingStrategies { get; set; } = new();
    public List<RagasQuestionItem> Questions { get; set; } = new();
    public BenchmarkReadinessViewModel Readiness { get; set; } = new();
}

public sealed class RagasEmbeddingModelOption
{
    public string Key { get; set; } = string.Empty;
    public string Provider { get; set; } = string.Empty;
    public string Model { get; set; } = string.Empty;
    public bool IsSelected { get; set; }
}

public sealed class RagasChunkingStrategyOption
{
    public string Key { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public bool IsSelected { get; set; }
}

public sealed class RagasQuestionItem
{
    public int Id { get; set; }
    public string Question { get; set; } = string.Empty;
    public string GroundTruthAnswer { get; set; } = string.Empty;
    public bool IsAnswerable { get; set; }
    public bool IsBenchmarkReady { get; set; }
    public int GoldChunkCount { get; set; }
    public string? CreatedByName { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class BenchmarkReadinessViewModel
{
    public bool IsReady { get; set; }
    public int TotalQuestions { get; set; }
    public int ReadyQuestions { get; set; }
    public int AnswerableQuestions { get; set; }
    public int UnanswerableQuestions { get; set; }
    public List<string> Errors { get; set; } = new();
}

public sealed class RagasAddQuestionViewModel
{
    public int SubjectId { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập câu hỏi.")]
    public string Question { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập câu trả lời chuẩn.")]
    public string GroundTruthAnswer { get; set; } = string.Empty;
}

public sealed class RagasEditQuestionViewModel
{
    public int Id { get; set; }
    public int SubjectId { get; set; }

    [Required(ErrorMessage = "Vui lòng nhập câu hỏi.")]
    public string Question { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập câu trả lời chuẩn.")]
    public string GroundTruthAnswer { get; set; } = string.Empty;
}

public sealed class RagasRunResultViewModel
{
    public int SubjectId { get; set; }
    public string SubjectName { get; set; } = string.Empty;
    public string RunId { get; set; } = string.Empty;
    public string EmbeddingModel { get; set; } = string.Empty;
    public string? LlmModel { get; set; }
    public string ChunkingStrategy { get; set; } = string.Empty;
    public int QuestionCount { get; set; }
    public decimal AvgRecallAt5 { get; set; }
    public decimal AvgMrrAt10 { get; set; }
    public decimal AvgNdcgAt5 { get; set; }
    public decimal AvgAnswerCorrectness { get; set; }
    public decimal AvgFaithfulness { get; set; }
    public decimal AvgCitationF1 { get; set; }
    public decimal? NoAnswerF1 { get; set; }
    public long EndToEndLatencyP50Ms { get; set; }
    public long EndToEndLatencyP95Ms { get; set; }
    public DateTime RunDate { get; set; }
    public List<RagasModelSummaryItem> ModelSummaries { get; set; } = new();
    public List<RagasTokenUsageSummaryItem> WeeklyTokenUsage { get; set; } = new();
    public List<RagasResultDetailItem> Results { get; set; } = new();
    public List<RagasModelResultGroupViewModel> ResultGroups { get; set; } = new();
}

public sealed class RagasModelResultGroupViewModel
{
    public string EmbeddingModel { get; set; } = string.Empty;
    public List<string> ChunkingStrategies { get; set; } = new();
    public List<RagasResultDetailItem> Results { get; set; } = new();
}

public sealed class RagasRunHistoryViewModel
{
    public int SubjectId { get; set; }
    public string SubjectName { get; set; } = string.Empty;
    public int PageNumber { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public int TotalRuns { get; set; }
    public int TotalPages => Math.Max(1, (int)Math.Ceiling(TotalRuns / (double)PageSize));
    public List<RagasRunHistoryItemViewModel> Items { get; set; } = new();
}

public sealed class RagasRunHistoryItemViewModel
{
    public string RunId { get; set; } = string.Empty;
    public DateTime RunDate { get; set; }
    public List<string> EmbeddingModels { get; set; } = new();
    public List<string> ChunkingStrategies { get; set; } = new();
    public int QuestionCount { get; set; }
    public decimal AvgRecallAt5 { get; set; }
}

public sealed class RagasModelSummaryItem
{
    public string EmbeddingModel { get; set; } = string.Empty;
    public string? LlmModel { get; set; }
    public string? VectorStore { get; set; }
    public string ChunkingStrategy { get; set; } = string.Empty;
    public int QuestionCount { get; set; }
    public decimal AvgRecallAt5 { get; set; }
    public decimal AvgMrrAt10 { get; set; }
    public decimal AvgNdcgAt5 { get; set; }
    public decimal AvgAnswerCorrectness { get; set; }
    public decimal AvgFaithfulness { get; set; }
    public decimal AvgCitationF1 { get; set; }
    public decimal? NoAnswerF1 { get; set; }
    public long EmbeddingLatencyP50Ms { get; set; }
    public long EmbeddingLatencyP95Ms { get; set; }
    public long RetrievalLatencyP50Ms { get; set; }
    public long RetrievalLatencyP95Ms { get; set; }
    public long EndToEndLatencyP50Ms { get; set; }
    public long EndToEndLatencyP95Ms { get; set; }
}

public sealed class RagasTokenUsageSummaryItem
{
    public string EmbeddingModel { get; set; } = string.Empty;
    public string? LlmModel { get; set; }
    public int RunCount { get; set; }
    public int QuestionCount { get; set; }
    public int EstimatedEmbeddingTokens { get; set; }
    public int EstimatedPromptTokens { get; set; }
    public int EstimatedCompletionTokens { get; set; }
    public int EstimatedTotalTokens { get; set; }
    public decimal AvgRecallAt5 { get; set; }
    public DateTime FromUtc { get; set; }
    public DateTime ToUtc { get; set; }
}

public sealed class RagasResultDetailItem
{
    public string EmbeddingModel { get; set; } = string.Empty;
    public string ChunkingStrategy { get; set; } = string.Empty;
    public string Question { get; set; } = string.Empty;
    public string? GroundTruthAnswer { get; set; }
    public string? GeneratedAnswer { get; set; }
    public bool IsAnswerable { get; set; }
    public IReadOnlyList<int> RetrievedChunkIds { get; set; } = [];
    public IReadOnlyList<int> CitationChunkIds { get; set; } = [];
    public decimal? RecallAt5 { get; set; }
    public decimal? MrrAt10 { get; set; }
    public decimal? NdcgAt5 { get; set; }
    public decimal? AnswerCorrectness { get; set; }
    public decimal? Faithfulness { get; set; }
    public decimal? CitationPrecision { get; set; }
    public decimal? CitationRecall { get; set; }
    public decimal? CitationF1 { get; set; }
    public bool ExpectedNoAnswer { get; set; }
    public bool PredictedNoAnswer { get; set; }
    public long EmbeddingLatencyMs { get; set; }
    public long RetrievalLatencyMs { get; set; }
    public long GenerationLatencyMs { get; set; }
    public long EndToEndLatencyMs { get; set; }
}

public sealed class RagasQuestionSetupViewModel
{
    public int QuestionId { get; set; }
    public int SubjectId { get; set; }
    public string SubjectName { get; set; } = string.Empty;
    public string Question { get; set; } = string.Empty;
    public string GroundTruthAnswer { get; set; } = string.Empty;
    public bool IsAnswerable { get; set; } = true;
    public bool IsBenchmarkReady { get; set; }
    public string? SearchTerm { get; set; }
    public List<RagasChunkCandidateViewModel> Candidates { get; set; } = new();
}

public sealed class RagasChunkCandidateViewModel
{
    public int ChunkId { get; set; }
    public string DocumentTitle { get; set; } = string.Empty;
    public string OriginalFileName { get; set; } = string.Empty;
    public int ChunkIndex { get; set; }
    public int? PageNumber { get; set; }
    public int? SlideNumber { get; set; }
    public string Content { get; set; } = string.Empty;
    public decimal SuggestionScore { get; set; }
    public bool IsSelected { get; set; }
    public byte RelevanceGrade { get; set; } = 2;
}
public sealed class RagasQuestionSetupInputModel
{
    public int QuestionId { get; set; }
    public bool IsAnswerable { get; set; } = true;
    public List<RagasChunkSelectionInputModel> Candidates { get; set; } = new();
}

public sealed class RagasChunkSelectionInputModel
{
    public int ChunkId { get; set; }
    public bool IsSelected { get; set; }
    public byte RelevanceGrade { get; set; } = 2;
}
