namespace BusinessLogic.Infrastructure.Events;

public class ChatCompletedEvent
{
    public int SchemaVersion { get; set; } = 1;
    public Guid EventId { get; set; }
    public Guid MessageId { get; set; }
    public Guid RequestId { get; set; }
    public string? TraceParent { get; set; }
    public Guid UserId { get; set; }

    public Guid SessionId { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public string Response { get; set; } = string.Empty;

    public int TokensUsed { get; set; }

    public bool IsViolation { get; set; }

    public List<string> ViolationKeywords { get; set; } = new();

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
