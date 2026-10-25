using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class LearningAttemptRepository : GenericRepository<LearningAttempt>, ILearningAttemptRepository
{
    public LearningAttemptRepository(ChatAIWebDbContext context)
        : base(context)
    {
    }

    public Task<LearningAttempt?> GetOwnedAsync(
        Guid attemptId,
        Guid userId,
        bool includeAnswers,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet.Where(a => a.Id == attemptId && a.UserId == userId);
        if (includeAnswers)
        {
            query = query.Include(a => a.Answers.OrderBy(answer => answer.Position));
        }

        return query.FirstOrDefaultAsync(cancellationToken);
    }

    public Task<LearningAttempt?> GetInProgressAsync(
        Guid userId,
        Guid bankId,
        AttemptMode mode,
        CancellationToken cancellationToken = default)
    {
        return DbSet
            .Where(a => a.UserId == userId && a.BankId == bankId && a.Mode == mode && a.Status == AttemptStatus.InProgress)
            .OrderByDescending(a => a.StartedAt)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public Task<AttemptAnswer?> GetAnswerAsync(
        Guid attemptId,
        Guid questionId,
        CancellationToken cancellationToken = default)
    {
        return Context.AttemptAnswers.FirstOrDefaultAsync(a => a.AttemptId == attemptId && a.QuestionId == questionId, cancellationToken);
    }

    public async Task<IReadOnlyList<Guid>> GetExpiredExamIdsAsync(
        DateTime utcNow,
        int take,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(a => a.Status == AttemptStatus.InProgress && a.DeadlineAt != null && a.DeadlineAt <= utcNow)
            .OrderBy(a => a.DeadlineAt)
            .Select(a => a.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }
}
