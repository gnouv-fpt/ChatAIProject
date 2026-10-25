using BusinessObject.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace DataAccess;

public class ChatAIWebDbContext : DbContext
{
    public ChatAIWebDbContext(DbContextOptions<ChatAIWebDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();

    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    public DbSet<LegalDocument> LegalDocuments => Set<LegalDocument>();

    public DbSet<DocumentChunk> DocumentChunks => Set<DocumentChunk>();

    public DbSet<ChatSession> ChatSessions => Set<ChatSession>();

    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();

    public DbSet<Citation> Citations => Set<Citation>();

    public DbSet<ChatAttachment> ChatAttachments => Set<ChatAttachment>();

    public DbSet<QuestionBank> QuestionBanks => Set<QuestionBank>();

    public DbSet<Question> Questions => Set<Question>();

    public DbSet<ExamTemplate> ExamTemplates => Set<ExamTemplate>();

    public DbSet<LearningAttempt> LearningAttempts => Set<LearningAttempt>();

    public DbSet<AttemptAnswer> AttemptAnswers => Set<AttemptAnswer>();

    public DbSet<QuestionBookmark> QuestionBookmarks => Set<QuestionBookmark>();

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        configurationBuilder.Properties<Enum>().HaveConversion<string>().HaveMaxLength(30);
        // All timestamps are stored as UTC; restore Kind on read so JSON serializes with a "Z" suffix.
        configurationBuilder.Properties<DateTime>().HaveConversion<UtcDateTimeConverter>();
    }

    private sealed class UtcDateTimeConverter()
        : ValueConverter<DateTime, DateTime>(v => v, v => DateTime.SpecifyKind(v, DateTimeKind.Utc));

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            entity.Property(u => u.Username).HasMaxLength(50);
            entity.Property(u => u.Email).HasMaxLength(256);
            entity.Property(u => u.PasswordHash).HasMaxLength(256);
            entity.HasIndex(u => u.Username).IsUnique();
            entity.HasIndex(u => u.Email).IsUnique();
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_Users_TokenQuota", "[TokenQuota] >= 0");
                t.HasCheckConstraint("CK_Users_TokenBalance", "[TokenBalance] >= 0");
            });
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.Property(t => t.TokenHash).HasMaxLength(128);
            entity.HasIndex(t => t.TokenHash).IsUnique();
            entity.HasOne(t => t.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(t => t.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<LegalDocument>(entity =>
        {
            entity.Property(d => d.DocumentNumber).HasMaxLength(100);
            entity.Property(d => d.Title).HasMaxLength(500);
            entity.Property(d => d.IssuingAuthority).HasMaxLength(255);
            entity.Property(d => d.SourceUrl).HasMaxLength(1000);
            entity.Property(d => d.ContentHash).HasMaxLength(64);
            entity.Property(d => d.Version).HasDefaultValue(1);
            entity.HasIndex(d => d.DocumentNumber).IsUnique();
            entity.HasIndex(d => new { d.IsActive, d.VerificationStatus });
            // Relay scan for pending document-updated-events.
            entity.HasIndex(d => d.CreatedAt)
                .HasDatabaseName("IX_LegalDocuments_UnpublishedEvents")
                .HasFilter("[EventPayload] IS NOT NULL AND [EventPublishedAt] IS NULL");
            entity.ToTable(t => t.HasCheckConstraint("CK_LegalDocuments_Version", "[Version] >= 1"));
        });

        modelBuilder.Entity<DocumentChunk>(entity =>
        {
            entity.Property(c => c.Chapter).HasMaxLength(100);
            entity.Property(c => c.Article).HasMaxLength(100);
            entity.Property(c => c.Clause).HasMaxLength(100);
            entity.Property(c => c.Point).HasMaxLength(50);
            entity.Property(c => c.VectorId).HasMaxLength(100);
            entity.HasOne(c => c.Document)
                .WithMany(d => d.Chunks)
                .HasForeignKey(c => c.DocumentId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ChatSession>(entity =>
        {
            entity.Property(s => s.Title).HasMaxLength(255);
            entity.HasIndex(s => new { s.UserId, s.IsDeleted, s.LastUpdatedAt });
            entity.HasOne(s => s.User)
                .WithMany(u => u.ChatSessions)
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ChatMessage>(entity =>
        {
            entity.Property(m => m.RequestHash).HasMaxLength(64);
            entity.Property(m => m.TurnState).HasMaxLength(20);
            entity.Property(m => m.ResultStatus).HasMaxLength(30);
            entity.HasIndex(m => new { m.SessionId, m.RequestId }).IsUnique()
                .HasFilter("[RequestId] IS NOT NULL");
            entity.HasIndex(m => new { m.SessionId, m.CreatedAt });
            // Relay scan for pending chat-completed-events.
            entity.HasIndex(m => m.CreatedAt)
                .HasDatabaseName("IX_ChatMessages_UnpublishedEvents")
                .HasFilter("[EventPayload] IS NOT NULL AND [EventPublishedAt] IS NULL");
            // Quota scan for reservations that still hold budget.
            entity.HasIndex(m => new { m.TurnState, m.LeaseExpiresAt })
                .HasDatabaseName("IX_ChatMessages_OpenReservations")
                .HasFilter("[QuotaSettledAt] IS NULL AND [ReservedTokens] > 0");
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_ChatMessages_TurnState",
                    "[TurnState] IS NULL OR [TurnState] IN ('Processing', 'Completed', 'Failed')");
                t.HasCheckConstraint("CK_ChatMessages_Tokens", "[TokensUsed] >= 0 AND [ReservedTokens] >= 0");
                // A turn keyed by RequestId always stores the payload hash used for replay checks.
                t.HasCheckConstraint("CK_ChatMessages_Request", "[RequestId] IS NULL OR [RequestHash] IS NOT NULL");
            });
            entity.HasOne(m => m.Session)
                .WithMany(s => s.Messages)
                .HasForeignKey(m => m.SessionId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Citation>(entity =>
        {
            entity.Property(c => c.ContentHash).HasMaxLength(64);
            entity.Property(c => c.PointNumber).HasMaxLength(50);
            entity.Property(c => c.DocumentTitle).HasMaxLength(500);
            entity.Property(c => c.ArticleNumber).HasMaxLength(50);
            entity.Property(c => c.ClauseNumber).HasMaxLength(50);
            entity.Property(c => c.SourceUrl).HasMaxLength(1000);
            entity.HasOne(c => c.ChatMessage)
                .WithMany(m => m.Citations)
                .HasForeignKey(c => c.ChatMessageId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(c => c.DocumentChunk)
                .WithMany(ch => ch.Citations)
                .HasForeignKey(c => c.DocumentChunkId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<ChatAttachment>(entity =>
        {
            entity.Property(a => a.StorageKey).HasMaxLength(300);
            entity.Property(a => a.ContentType).HasMaxLength(100);
            entity.Property(a => a.Sha256).HasMaxLength(64);
            entity.HasIndex(a => a.StorageKey).IsUnique();
            entity.HasIndex(a => new { a.UserId, a.DeletedAt });
            entity.HasIndex(a => a.ExpiresAt).HasFilter("[DeletedAt] IS NULL");
            entity.ToTable(t => t.HasCheckConstraint("CK_ChatAttachments_Size", "[SizeBytes] > 0"));
            // Users -> ChatSessions -> ChatAttachments already cascades; SQL Server rejects a second path.
            entity.HasOne(a => a.User)
                .WithMany()
                .HasForeignKey(a => a.UserId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(a => a.Session)
                .WithMany()
                .HasForeignKey(a => a.SessionId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        ConfigureLearning(modelBuilder);
    }

    private static void ConfigureLearning(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<QuestionBank>(entity =>
        {
            entity.Property(b => b.Code).HasMaxLength(50);
            entity.Property(b => b.Name).HasMaxLength(255);
            entity.Property(b => b.LicenseClass).HasMaxLength(20);
            entity.Property(b => b.Description).HasMaxLength(1000);
            entity.Property(b => b.SourceName).HasMaxLength(255);
            entity.Property(b => b.SourceUrl).HasMaxLength(1000);
            entity.Property(b => b.ManifestHash).HasMaxLength(64);
            entity.HasIndex(b => new { b.Code, b.Version }).IsUnique();
            entity.HasIndex(b => b.Status);
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_QuestionBanks_Version", "[Version] >= 1");
                t.HasCheckConstraint("CK_QuestionBanks_QuestionCount", "[QuestionCount] >= 0");
                t.HasCheckConstraint("CK_QuestionBanks_Published", "[Status] <> 'Published' OR [PublishedAt] IS NOT NULL");
            });
        });

        modelBuilder.Entity<Question>(entity =>
        {
            entity.Property(q => q.ExternalId).HasMaxLength(100);
            entity.Property(q => q.ImagePath).HasMaxLength(500);
            entity.Property(q => q.Topic).HasMaxLength(100);
            entity.Property(q => q.LegalReference).HasMaxLength(500);
            entity.Property(q => q.ContentHash).HasMaxLength(64);
            entity.OwnsMany(q => q.Options, options =>
            {
                options.ToJson();
                options.Property(o => o.OptionId).HasJsonPropertyName("id");
                options.Property(o => o.Text).HasJsonPropertyName("text");
            });
            entity.HasIndex(q => new { q.BankId, q.Number }).IsUnique();
            entity.HasIndex(q => new { q.BankId, q.ExternalId }).IsUnique();
            entity.HasIndex(q => new { q.BankId, q.Topic });
            entity.ToTable(t => t.HasCheckConstraint("CK_Questions_Number", "[Number] >= 1"));
            entity.HasOne(q => q.Bank)
                .WithMany(b => b.Questions)
                .HasForeignKey(q => q.BankId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ExamTemplate>(entity =>
        {
            entity.Property(t => t.Code).HasMaxLength(50);
            entity.Property(t => t.Name).HasMaxLength(255);
            entity.Property(t => t.SourceName).HasMaxLength(255);
            entity.HasIndex(t => new { t.BankId, t.Code }).IsUnique();
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_ExamTemplates_QuestionCount", "[QuestionCount] >= 1");
                t.HasCheckConstraint("CK_ExamTemplates_Duration", "[DurationMinutes] >= 1");
                t.HasCheckConstraint("CK_ExamTemplates_PassingScore", "[PassingScore] >= 0 AND [PassingScore] <= [QuestionCount]");
            });
            entity.HasOne(t => t.Bank)
                .WithMany(b => b.ExamTemplates)
                .HasForeignKey(t => t.BankId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<LearningAttempt>(entity =>
        {
            entity.Property(a => a.RowVersion).IsRowVersion();
            entity.Property(a => a.FailReason).HasMaxLength(500);
            entity.HasIndex(a => new { a.UserId, a.BankId, a.Status });
            entity.HasIndex(a => new { a.UserId, a.StartedAt });
            // Expiry job: in-progress exams past their deadline.
            entity.HasIndex(a => a.DeadlineAt).HasFilter("[Status] = 'InProgress' AND [DeadlineAt] IS NOT NULL");
            entity.ToTable(t =>
            {
                t.HasCheckConstraint("CK_LearningAttempts_QuestionCount", "[QuestionCount] >= 1");
                t.HasCheckConstraint("CK_LearningAttempts_ExamDeadline", "[Mode] <> 'Exam' OR [DeadlineAt] IS NOT NULL");
                t.HasCheckConstraint("CK_LearningAttempts_Graded",
                    "[Status] IN ('InProgress', 'Abandoned') OR [SubmittedAt] IS NOT NULL");
            });
            entity.HasOne(a => a.User)
                .WithMany()
                .HasForeignKey(a => a.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            // Attempts keep their bank version; a bank version with history cannot be deleted.
            entity.HasOne(a => a.Bank)
                .WithMany()
                .HasForeignKey(a => a.BankId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(a => a.ExamTemplate)
                .WithMany()
                .HasForeignKey(a => a.ExamTemplateId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<AttemptAnswer>(entity =>
        {
            entity.HasIndex(a => new { a.AttemptId, a.QuestionId }).IsUnique();
            entity.HasIndex(a => new { a.AttemptId, a.Position }).IsUnique();
            entity.HasIndex(a => a.QuestionId);
            entity.ToTable(t => t.HasCheckConstraint("CK_AttemptAnswers_Position", "[Position] >= 1"));
            entity.HasOne(a => a.Attempt)
                .WithMany(t => t.Answers)
                .HasForeignKey(a => a.AttemptId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(a => a.Question)
                .WithMany()
                .HasForeignKey(a => a.QuestionId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<QuestionBookmark>(entity =>
        {
            entity.HasIndex(b => new { b.UserId, b.QuestionId }).IsUnique();
            entity.HasOne(b => b.User)
                .WithMany()
                .HasForeignKey(b => b.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(b => b.Question)
                .WithMany()
                .HasForeignKey(b => b.QuestionId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
