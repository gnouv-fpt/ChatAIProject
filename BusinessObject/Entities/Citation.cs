namespace BusinessObject.Entities;

public class Citation
{
    public Guid Id { get; set; }

    public Guid ChatMessageId { get; set; }

    // Nullable: the gRPC CitationDto carries title/article/clause but no chunk id.
    public Guid? DocumentChunkId { get; set; }

    public string? DocumentTitle { get; set; }

    public string? ArticleNumber { get; set; }

    public string? ClauseNumber { get; set; }

    public string? Excerpt { get; set; }

    public string? SourceUrl { get; set; }

    public ChatMessage ChatMessage { get; set; } = null!;

    public DocumentChunk? DocumentChunk { get; set; }
}
