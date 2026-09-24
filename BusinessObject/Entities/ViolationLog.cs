namespace BusinessObject.Entities;

public class ViolationLog
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    // Nullable: ChatCompletedEvent carries SessionId but no message id.
    public Guid? ChatMessageId { get; set; }

    public string ViolationKeywords { get; set; } = string.Empty;

    public bool NotifiedViaEmail { get; set; }

    public DateTime CreatedAt { get; set; }

    public User User { get; set; } = null!;

    public ChatMessage? ChatMessage { get; set; }
}
