namespace BusinessObject.Entities;

public class Citation
{
    public Guid Id { get; set; }

    public Guid ChatMessageId { get; set; }

    // Nullable only for historical citations created before contract v2.
    public Guid? DocumentChunkId { get; set; }
    public string? ContentHash { get; set; }
    public string? PointNumber { get; set; }

    public string? DocumentTitle { get; set; }

    public string? ArticleNumber { get; set; }

    public string? ClauseNumber { get; set; }

    public string? Excerpt { get; set; }

    public string? SourceUrl { get; set; }

    public ChatMessage ChatMessage { get; set; } = null!;

    public DocumentChunk? DocumentChunk { get; set; }
}
