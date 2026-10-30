using BusinessObject.Enums;
using DataAccess.Models;

namespace DataAccess.Repositories.Interfaces;

// Read-only queries behind progress/history. Rules such as "which answers count" live in LearningProgressService.
public interface ILearningProgressRepository
{
    Task<IReadOnlyList<AnswerHistoryRow>> GetAnswerHistoryAsync(
        Guid userId,
        Guid bankId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<AttemptSummaryRow>> GetAttemptSummariesAsync(
        Guid userId,
        Guid bankId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Guid>> GetBankIdsWithActivityAsync(Guid userId, CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<AttemptHistoryRow> Items, int TotalCount)> GetAttemptHistoryAsync(
        Guid userId,
        Guid? bankId,
        AttemptMode? mode,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default);
}
