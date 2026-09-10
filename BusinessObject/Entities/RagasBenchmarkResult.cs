using System;
using System.Collections.Generic;

namespace BusinessObject.Entities;

public partial class RagasBenchmarkResult
{
    public int Id { get; set; }

    public int EvaluationQuestionId { get; set; }

    public string RunId { get; set; } = null!;

    public string EmbeddingModel { get; set; } = null!;

    public string? LlmModel { get; set; }

    public string? VectorStore { get; set; }

    public string ChunkingStrategy { get; set; } = null!;

    public string? GeneratedAnswer { get; set; }

    public string? RetrievedContextsJson { get; set; }

    public string? RetrievedChunkIdsJson { get; set; }

    public string? CitationChunkIdsJson { get; set; }

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





    public DateTime CreatedAt { get; set; }

    public virtual EvaluationQuestion EvaluationQuestion { get; set; } = null!;
}
