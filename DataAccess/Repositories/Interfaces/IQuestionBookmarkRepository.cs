using BusinessObject.Entities;
using DataAccess.Models;

namespace DataAccess.Repositories.Interfaces;

public interface IQuestionBookmarkRepository : IGenericRepository<QuestionBookmark>
{
    Task<QuestionBookmark?> GetAsync(Guid userId, Guid questionId, CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<BookmarkRow> Items, int TotalCount)> GetPagedAsync(
        Guid userId,
        IReadOnlyCollection<Guid>? questionIds,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Guid>> GetQuestionIdsAsync(Guid userId, CancellationToken cancellationToken = default);
}
