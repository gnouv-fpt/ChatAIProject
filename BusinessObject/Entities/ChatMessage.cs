using BusinessObject.Enums;

namespace BusinessObject.Entities;

public class ChatMessage
{
    public Guid Id { get; set; }

    public Guid SessionId { get; set; }

    public SenderRole SenderRole { get; set; }

    public string Content { get; set; } = null!;

    public int TokensUsed { get; set; }

    public bool IsViolation { get; set; }

    public DateTime CreatedAt { get; set; }

    // Durable turn/outbox state. Null state denotes a legacy message.
    public Guid? RequestId { get; set; }
    public string? RequestHash { get; set; }
    public string? TurnState { get; set; }
    public Guid? LeaseId { get; set; }
    public DateTime? LeaseExpiresAt { get; set; }
    public int ReservedTokens { get; set; }
    public string? RequestContext { get; set; }
    public string? ResultStatus { get; set; }
    public string? EventPayload { get; set; }
    public DateTime? EventPublishedAt { get; set; }
    public DateTime? QuotaSettledAt { get; set; }

    public ChatSession Session { get; set; } = null!;

    public ICollection<Citation> Citations { get; set; } = new List<Citation>();
}
