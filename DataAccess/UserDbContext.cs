using System.Text.Json;
using BusinessObject.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;

namespace DataAccess;

public sealed class UserDbContext(DbContextOptions<UserDbContext> options) : TrafficDbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<ChatSession> ChatSessions => Set<ChatSession>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<ExamAttempt> ExamAttempts => Set<ExamAttempt>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Ignore<RefreshToken>();
        model.Ignore<LegalDocument>();
        model.Ignore<DocumentChunk>();
        model.Ignore<Citation>();
        model.Entity<User>(e =>
        {
            e.ToTable("Users");
            e.Ignore(u => u.RefreshTokens); // Legacy CLR navigation, never mapped in the new database.
            e.Property(u => u.Username).HasMaxLength(50);
            e.Property(u => u.Email).HasMaxLength(256);
            e.Property(u => u.PasswordHash).HasMaxLength(256);
            e.HasIndex(u => u.Username).IsUnique();
            e.HasIndex(u => u.Email).IsUnique();
        });
        model.Entity<ChatSession>(e =>
        {
            e.ToTable("UserChatSessions");
            e.Property(s => s.Title).HasMaxLength(255);
            e.HasIndex(s => new { s.UserId, s.IsDeleted, s.LastUpdatedAt });
            e.HasOne(s => s.User).WithMany(u => u.ChatSessions).HasForeignKey(s => s.UserId);
        });
        model.Entity<ChatMessage>(e =>
        {
            e.ToTable("UserChatMessages");
            e.Property(m => m.RequestHash).HasMaxLength(64);
            e.Property(m => m.TurnState).HasMaxLength(20);
            e.Property(m => m.ResultStatus).HasMaxLength(30);
            e.HasIndex(m => new { m.SessionId, m.RequestId }).IsUnique().HasFilter("[RequestId] IS NOT NULL");
            e.HasIndex(m => new { m.SessionId, m.CreatedAt });
            e.HasOne(m => m.Session).WithMany(s => s.Messages).HasForeignKey(m => m.SessionId);
            // Logical chunk IDs and citation evidence are snapshots, with no cross-database FK.
            e.Property(m => m.Citations).HasColumnName("CitationsJson")
                .HasConversion(v => SerializeCitations(v), v => DeserializeCitations(v))
                .Metadata.SetValueComparer(new ValueComparer<ICollection<Citation>>(
                    (a, b) => SerializeCitations(a!) == SerializeCitations(b!),
                    v => SerializeCitations(v).GetHashCode(),
                    v => DeserializeCitations(SerializeCitations(v))));
        });
        model.Entity<ExamAttempt>(e =>
        {
            e.ToTable("ExamAttempts", t =>
            {
                t.HasCheckConstraint("CK_ExamAttempts_Score", "[Score] >= 0");
                t.HasCheckConstraint("CK_ExamAttempts_Time", "[TimeSpentSeconds] >= 0");
                t.HasCheckConstraint("CK_ExamAttempts_Version", "[ExamVersion] > 0");
                t.HasCheckConstraint("CK_ExamAttempts_AnswersJson", "ISJSON([UserAnswersJson]) = 1");
                t.HasCheckConstraint("CK_ExamAttempts_SnapshotJson", "ISJSON([ExamSnapshotJson]) = 1");
            });
            e.Property(a => a.ExamCode).HasMaxLength(100);
            e.Property(a => a.SubmissionHash).HasMaxLength(64);
            e.HasIndex(a => new { a.UserId, a.SubmittedAt });
            e.HasOne(a => a.User).WithMany().HasForeignKey(a => a.UserId).OnDelete(DeleteBehavior.Restrict);
            // Id is the stable attempt/idempotency key. ExamCode is a logical reference only.
        });
    }

    private static string SerializeCitations(ICollection<Citation> value) => JsonSerializer.Serialize(value);
    private static ICollection<Citation> DeserializeCitations(string value) =>
        JsonSerializer.Deserialize<List<Citation>>(value) ?? [];
}
