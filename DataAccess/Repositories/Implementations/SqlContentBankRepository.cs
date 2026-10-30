using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

// Import metadata is retained in the existing JSON column, alongside the question snapshot.
public sealed class SqlContentBankRepository(ContentDbContext db) : IContentBankRepository
{
    public sealed record Payload(ContentBank Header, BankQuestion Question, string Hash,
        DateTime ImportedAt, Guid ImportedBy, DateTime? PublishedAt);

    public async Task<IReadOnlyList<QuestionBankPackage>> ListAsync(CancellationToken cancellationToken = default) =>
        Packages(await db.TrafficQuestions.AsNoTracking().ToListAsync(cancellationToken));

    public async Task<QuestionBankPackage?> GetAsync(Guid id, string version, CancellationToken cancellationToken = default)
    {
        var code = id.ToString("N");
        if (!int.TryParse(version, out var revision)) return null;
        return Packages(await db.TrafficQuestions.AsNoTracking()
            .Where(q => q.BankCode == code && q.BankVersion == revision).ToListAsync(cancellationToken)).SingleOrDefault();
    }

    public async Task<bool> AddAsync(QuestionBankPackage package, CancellationToken cancellationToken = default)
    {
        var bank = package.Bank;
        var revision = int.Parse(bank.Version, System.Globalization.CultureInfo.InvariantCulture);
        var code = bank.Id.ToString("N");
        return await db.Database.CreateExecutionStrategy().ExecuteAsync(async () =>
        {
            db.ChangeTracker.Clear();
            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, cancellationToken);
            if (await db.TrafficQuestions.AnyAsync(q => q.BankCode == code && q.BankVersion == revision, cancellationToken)) return false;
            var ids = bank.Questions.Select(q => q.Id).ToArray();
            if (await db.TrafficQuestions.AnyAsync(q => ids.Contains(q.Id), cancellationToken)) return false;
            foreach (var question in bank.Questions)
            {
                var categoryId = new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(question.CategoryType + "|" + question.Topic)).AsSpan(0, 16));
                if (await db.QuestionCategories.FindAsync([categoryId], cancellationToken) is null)
                    db.QuestionCategories.Add(new TrafficQuestionCategory { Id = categoryId, Type = question.CategoryType,
                        SubCategoryCode = categoryId.ToString("N"), Name = question.Topic });
                db.TrafficQuestions.Add(new TrafficQuestion
                {
                    Id = question.Id, BankCode = code, BankVersion = revision, QuestionCode = question.Number.ToString(),
                    CategoryId = categoryId, IsParalysisQuestion = question.IsCritical, AllowOptionShuffle = question.AllowOptionShuffle,
                    CorrectAnswerKey = question.CorrectOptionIds.Single(), ExplanationText = question.Explanation,
                    ExplanationAnimationUrl = question.ExplanationAnimationUrl,
                    SourceUrl = question.SourceUrl, CreatedAt = package.ImportedAt,
                    QuestionPayloadJson = JsonSerializer.Serialize(new Payload(bank with { Questions = [] }, question,
                        package.Hash, package.ImportedAt, package.ImportedBy, null))
                });
            }
            await db.SaveChangesAsync(cancellationToken);
            await tx.CommitAsync(cancellationToken);
            return true;
        });
    }

    public async Task<bool> PublishAsync(Guid id, string version, string expectedHash, CancellationToken cancellationToken = default)
    {
        if (!int.TryParse(version, out var revision)) return false;
        var code = id.ToString("N");
        return await db.Database.CreateExecutionStrategy().ExecuteAsync(async () =>
        {
            db.ChangeTracker.Clear();
            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, cancellationToken);
            var rows = await db.TrafficQuestions.Where(q => q.BankCode == code && q.BankVersion == revision).ToListAsync(cancellationToken);
            if (rows.Count == 0) return false;
            foreach (var row in rows)
            {
                var payload = JsonSerializer.Deserialize<Payload>(row.QuestionPayloadJson)!;
                if (payload.Hash != expectedHash) return false;
                row.IsPublished = true;
                row.QuestionPayloadJson = JsonSerializer.Serialize(payload with { PublishedAt = payload.PublishedAt ?? DateTime.UtcNow });
            }
            await db.SaveChangesAsync(cancellationToken);
            await tx.CommitAsync(cancellationToken);
            return true;
        });
    }

    private static IReadOnlyList<QuestionBankPackage> Packages(List<TrafficQuestion> rows) => rows
        .GroupBy(q => (q.BankCode, q.BankVersion)).Select(group =>
        {
            var payloads = group.Select(q => JsonSerializer.Deserialize<Payload>(q.QuestionPayloadJson)!).ToList();
            var first = payloads[0];
            return new QuestionBankPackage(first.Header with { Questions = payloads.Select(p => p.Question).OrderBy(q => q.Number).ToList() },
                first.Hash, first.ImportedAt, first.ImportedBy, group.All(q => q.IsPublished), first.PublishedAt);
        }).ToList();
}
