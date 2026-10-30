using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class ExamAttemptRepository(UserDbContext db) : GenericRepository<ExamAttempt>(db), IExamAttemptRepository
{
    public Task<ExamAttempt> InsertOrGetAsync(ExamAttempt attempt, CancellationToken ct) =>
        db.Database.CreateExecutionStrategy().ExecuteAsync(async () =>
        {
            db.ChangeTracker.Clear();
            await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
            var existing = db.Database.IsSqlServer()
                ? await db.ExamAttempts.FromSqlInterpolated($"SELECT * FROM ExamAttempts WITH (UPDLOCK,HOLDLOCK) WHERE Id = {attempt.Id}").SingleOrDefaultAsync(ct)
                : await db.ExamAttempts.SingleOrDefaultAsync(a => a.Id == attempt.Id, ct);
            if (existing is not null) return existing;
            db.ExamAttempts.Add(attempt);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return attempt;
        });
    public Task<ExamAttempt?> GetOwnedAsync(Guid attemptId, Guid userId, CancellationToken ct) =>
        DbSet.AsNoTracking().SingleOrDefaultAsync(a => a.Id == attemptId && a.UserId == userId, ct);

    public async Task<IReadOnlyList<ExamAttempt>> GetHistoryAsync(Guid userId, int page, int pageSize, CancellationToken ct) =>
        await DbSet.AsNoTracking().Where(a => a.UserId == userId).OrderByDescending(a => a.SubmittedAt).ThenBy(a => a.Id)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
}
