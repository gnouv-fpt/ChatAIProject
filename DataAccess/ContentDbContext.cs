using BusinessObject.Entities;
using Microsoft.EntityFrameworkCore;

namespace DataAccess;

public sealed class ContentDbContext(DbContextOptions<ContentDbContext> options) : TrafficDbContext(options)
{
    public DbSet<LegalDocument> LegalDocuments => Set<LegalDocument>();
    public DbSet<DocumentChunk> DocumentChunks => Set<DocumentChunk>();
    public DbSet<TrafficQuestionCategory> QuestionCategories => Set<TrafficQuestionCategory>();
    public DbSet<TrafficQuestion> TrafficQuestions => Set<TrafficQuestion>();
    public DbSet<ExamTemplate> ExamTemplates => Set<ExamTemplate>();
    public DbSet<ExamTemplateItem> ExamTemplateItems => Set<ExamTemplateItem>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Ignore<Citation>();
        model.Entity<LegalDocument>(e =>
        {
            e.ToTable("LegalDocuments");
            e.Property(d => d.DocumentNumber).HasMaxLength(100);
            e.Property(d => d.Title).HasMaxLength(500);
            e.Property(d => d.IssuingAuthority).HasMaxLength(255);
            e.Property(d => d.SourceUrl).HasMaxLength(1000);
            e.Property(d => d.ContentHash).HasMaxLength(64);
            e.ToTable("LegalDocuments", t => t.HasCheckConstraint("CK_LegalDocuments_Version", "[Version] > 0"));
            e.HasIndex(d => d.DocumentNumber).IsUnique();
            e.HasIndex(d => new { d.IsActive, d.VerificationStatus });
        });
        model.Entity<DocumentChunk>(e =>
        {
            e.ToTable("LegalDocumentChunks");
            e.Ignore(c => c.Citations);
            e.Property(c => c.Chapter).HasMaxLength(100);
            e.Property(c => c.Article).HasMaxLength(100);
            e.Property(c => c.Clause).HasMaxLength(100);
            e.Property(c => c.Point).HasMaxLength(50);
            e.Property(c => c.VectorId).HasMaxLength(100);
            e.HasOne(c => c.Document).WithMany(d => d.Chunks).HasForeignKey(c => c.DocumentId);
        });
        model.Entity<TrafficQuestionCategory>(e =>
        {
            e.ToTable("TrafficQuestionCategories");
            e.Property(c => c.Type).HasMaxLength(30);
            e.Property(c => c.SubCategoryCode).HasMaxLength(50);
            e.Property(c => c.Name).HasMaxLength(255);
            e.HasIndex(c => c.SubCategoryCode).IsUnique();
            // TotalQuestions is derived by query, never a second mutable count.
        });
        model.Entity<TrafficQuestion>(e =>
        {
            e.ToTable("TrafficQuestions", t =>
            {
                t.HasCheckConstraint("CK_TrafficQuestions_Version", "[BankVersion] > 0");
                t.HasCheckConstraint("CK_TrafficQuestions_Payload", "ISJSON([QuestionPayloadJson]) = 1");
            });
            e.Property(q => q.BankCode).HasMaxLength(100);
            e.Property(q => q.QuestionCode).HasMaxLength(100);
            e.Property(q => q.CorrectAnswerKey).HasMaxLength(30);
            e.Property(q => q.ExplanationAnimationUrl).HasMaxLength(2000);
            e.Property(q => q.SourceUrl).HasMaxLength(2000);
            e.HasIndex(q => new { q.BankCode, q.BankVersion, q.QuestionCode }).IsUnique();
            e.HasIndex(q => new { q.IsPublished, q.CategoryId });
            e.HasOne(q => q.Category).WithMany(c => c.Questions).HasForeignKey(q => q.CategoryId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(q => q.LegalDocumentChunk).WithMany().HasForeignKey(q => q.LegalDocumentChunkId).OnDelete(DeleteBehavior.Restrict);
        });
        model.Entity<ExamTemplate>(e =>
        {
            e.ToTable("ExamTemplates", t =>
            {
                t.HasCheckConstraint("CK_ExamTemplates_Version", "[Version] > 0");
                t.HasCheckConstraint("CK_ExamTemplates_Duration", "[DurationMinutes] > 0");
                t.HasCheckConstraint("CK_ExamTemplates_PassingScore", "[PassingScore] >= 0");
            });
            e.Property(t => t.ExamCode).HasMaxLength(100);
            e.Property(t => t.Title).HasMaxLength(500);
            e.HasIndex(t => new { t.ExamCode, t.Version }).IsUnique();
        });
        model.Entity<ExamTemplateItem>(e =>
        {
            e.ToTable("ExamTemplateItems", t => t.HasCheckConstraint("CK_ExamTemplateItems_Order", "[OrderIndex] > 0"));
            e.HasIndex(i => new { i.ExamTemplateId, i.OrderIndex }).IsUnique();
            e.HasIndex(i => new { i.ExamTemplateId, i.QuestionId }).IsUnique();
            e.HasOne(i => i.ExamTemplate).WithMany(t => t.Items).HasForeignKey(i => i.ExamTemplateId);
            e.HasOne(i => i.Question).WithMany().HasForeignKey(i => i.QuestionId).OnDelete(DeleteBehavior.Restrict);
        });
    }
}
