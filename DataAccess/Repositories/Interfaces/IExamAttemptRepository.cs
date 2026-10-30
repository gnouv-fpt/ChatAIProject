using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IExamAttemptRepository : IGenericRepository<ExamAttempt>
{
    Task<ExamAttempt> InsertOrGetAsync(ExamAttempt attempt, CancellationToken cancellationToken);
    Task<ExamAttempt?> GetOwnedAsync(Guid attemptId, Guid userId, CancellationToken cancellationToken);
    Task<IReadOnlyList<ExamAttempt>> GetHistoryAsync(Guid userId, int page, int pageSize, CancellationToken cancellationToken);
}
