using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class ExamAttemptRepository(UserDbContext db) : GenericRepository<ExamAttempt>(db), IExamAttemptRepository
{
    public Task<ExamAttempt?> GetOwnedAsync(Guid attemptId, Guid userId, CancellationToken ct) =>
        DbSet.AsNoTracking().SingleOrDefaultAsync(a => a.Id == attemptId && a.UserId == userId, ct);

    public async Task<IReadOnlyList<ExamAttempt>> GetHistoryAsync(Guid userId, int page, int pageSize, CancellationToken ct) =>
        await DbSet.AsNoTracking().Where(a => a.UserId == userId).OrderByDescending(a => a.SubmittedAt).ThenBy(a => a.Id)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
}
