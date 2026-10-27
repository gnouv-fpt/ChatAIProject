namespace BusinessObject.Entities;

public class TrafficQuestion
{
    public Guid Id { get; set; }
    public Guid CategoryId { get; set; }
    public Guid? LegalDocumentChunkId { get; set; }
    public string BankCode { get; set; } = null!;
    public int BankVersion { get; set; }
    public string QuestionCode { get; set; } = null!;
    public bool IsParalysisQuestion { get; set; }
    public bool AllowOptionShuffle { get; set; }
    public string QuestionPayloadJson { get; set; } = "{}";
    public string CorrectAnswerKey { get; set; } = null!;
    public string ExplanationText { get; set; } = "";
    public string? ExplanationAnimationUrl { get; set; }
    public string? SourceUrl { get; set; }
    public bool IsPublished { get; set; }
    public DateTime CreatedAt { get; set; }
    public TrafficQuestionCategory Category { get; set; } = null!;
    public DocumentChunk? LegalDocumentChunk { get; set; }
}
