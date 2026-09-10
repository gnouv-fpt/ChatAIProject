namespace BusinessObject.Entities;

public sealed class EvaluationQuestionGoldChunk
{
    public int EvaluationQuestionId { get; set; }

    public int DocumentChunkId { get; set; }

    public byte RelevanceGrade { get; set; }

    public DateTime CreatedAt { get; set; }

    public EvaluationQuestion EvaluationQuestion { get; set; } = null!;

    public DocumentChunk DocumentChunk { get; set; } = null!;
}