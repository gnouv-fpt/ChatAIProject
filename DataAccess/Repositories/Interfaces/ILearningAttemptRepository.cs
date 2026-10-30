using BusinessObject.Entities;
using BusinessObject.Enums;

namespace DataAccess.Repositories.Interfaces;

// Persistence for the practice/exam engine (Khánh). Create an attempt together with all of its
// AttemptAnswers (the snapshot) in one SaveChangesAsync. Grading relies on LearningAttempt.RowVersion:
// a concurrent second submit fails with DbUpdateConcurrencyException and should re-read the stored result.
public interface ILearningAttemptRepository : IGenericRepository<LearningAttempt>
{
    // Tracked; null when the attempt does not exist or belongs to another user.
    Task<LearningAttempt?> GetOwnedAsync(
        Guid attemptId,
        Guid userId,
        bool includeAnswers,
        CancellationToken cancellationToken = default);

    Task<LearningAttempt?> GetInProgressAsync(
        Guid userId,
        Guid bankId,
        AttemptMode mode,
        CancellationToken cancellationToken = default);

    Task<AttemptAnswer?> GetAnswerAsync(
        Guid attemptId,
        Guid questionId,
        CancellationToken cancellationToken = default);

    // In-progress exams whose server deadline has passed, oldest first.
    Task<IReadOnlyList<Guid>> GetExpiredExamIdsAsync(
        DateTime utcNow,
        int take,
        CancellationToken cancellationToken = default);
}
