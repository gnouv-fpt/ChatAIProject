namespace BusinessObject.Entities;

// Metadata of a private image; the bytes live in private storage, never in SQL or ChatMessages.
public class ChatAttachment
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid SessionId { get; set; }

    public string StorageKey { get; set; } = null!;

    public string ContentType { get; set; } = null!;

    public long SizeBytes { get; set; }

    public string Sha256 { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public DateTime ExpiresAt { get; set; }

    public DateTime? DeletedAt { get; set; }

    public User User { get; set; } = null!;

    public ChatSession Session { get; set; } = null!;
}
