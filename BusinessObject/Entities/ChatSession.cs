namespace BusinessObject.Entities;

public class ChatSession
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Title { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public DateTime LastUpdatedAt { get; set; }

    public bool IsDeleted { get; set; }

    public User User { get; set; } = null!;

    public ICollection<ChatMessage> Messages { get; set; } = new List<ChatMessage>();
}
