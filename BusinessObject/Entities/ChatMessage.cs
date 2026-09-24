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

    public ChatSession Session { get; set; } = null!;

    public ICollection<Citation> Citations { get; set; } = new List<Citation>();
}
