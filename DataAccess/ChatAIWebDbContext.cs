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

    public DbSet<ViolationLog> ViolationLogs => Set<ViolationLog>();

    public DbSet<UsageReport> UsageReports => Set<UsageReport>();

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
            entity.HasIndex(d => d.DocumentNumber).IsUnique();
            entity.HasIndex(d => new { d.IsActive, d.VerificationStatus });
        });

        modelBuilder.Entity<DocumentChunk>(entity =>
        {
            entity.Property(c => c.Chapter).HasMaxLength(100);
            entity.Property(c => c.Article).HasMaxLength(100);
            entity.Property(c => c.Clause).HasMaxLength(100);
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
            entity.HasIndex(m => new { m.SessionId, m.CreatedAt });
            entity.HasOne(m => m.Session)
                .WithMany(s => s.Messages)
                .HasForeignKey(m => m.SessionId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Citation>(entity =>
        {
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

        modelBuilder.Entity<ViolationLog>(entity =>
        {
            entity.Property(v => v.ViolationKeywords).HasMaxLength(1000);
            entity.HasIndex(v => v.CreatedAt);
            entity.HasOne(v => v.User)
                .WithMany(u => u.ViolationLogs)
                .HasForeignKey(v => v.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            // NoAction: a second cascade path from Users (via ChatSessions) is rejected by SQL Server.
            entity.HasOne(v => v.ChatMessage)
                .WithMany()
                .HasForeignKey(v => v.ChatMessageId)
                .OnDelete(DeleteBehavior.ClientSetNull);
        });

        modelBuilder.Entity<UsageReport>(entity =>
        {
            entity.HasIndex(r => r.ReportDate).IsUnique();
        });
    }
}
