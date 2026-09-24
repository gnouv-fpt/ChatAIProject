using BusinessObject.Enums;

namespace BusinessObject.Entities;

public class User
{
    public Guid Id { get; set; }

    public string Username { get; set; } = null!;

    public string Email { get; set; } = null!;

    public string PasswordHash { get; set; } = null!;

    public UserRole Role { get; set; } = UserRole.User;

    public int TokenQuota { get; set; }

    public int TokenBalance { get; set; }

    public DateTime CreatedAt { get; set; }

    public ICollection<ChatSession> ChatSessions { get; set; } = new List<ChatSession>();

    public ICollection<ViolationLog> ViolationLogs { get; set; } = new List<ViolationLog>();

    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
}
