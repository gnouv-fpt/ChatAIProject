namespace BusinessLogic.Infrastructure.Events;

public class ChatCompletedEvent
{
    public Guid UserId { get; set; }

    public Guid SessionId { get; set; }

    public string Prompt { get; set; } = string.Empty;

    public string Response { get; set; } = string.Empty;

    public int TokensUsed { get; set; }

    public bool IsViolation { get; set; }

    public List<string> ViolationKeywords { get; set; } = new();

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
