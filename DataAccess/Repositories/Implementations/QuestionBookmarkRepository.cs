using BusinessObject.Entities;
using DataAccess.Models;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class QuestionBookmarkRepository : GenericRepository<QuestionBookmark>, IQuestionBookmarkRepository
{
    public QuestionBookmarkRepository(ChatAIWebDbContext context)
        : base(context)
    {
    }

    public Task<QuestionBookmark?> GetAsync(Guid userId, Guid questionId, CancellationToken cancellationToken = default)
    {
        return DbSet.FirstOrDefaultAsync(b => b.UserId == userId && b.QuestionId == questionId, cancellationToken);
    }

    public async Task<(IReadOnlyList<BookmarkRow> Items, int TotalCount)> GetPagedAsync(
        Guid userId,
        IReadOnlyCollection<Guid>? questionIds,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var bookmarks = DbSet.AsNoTracking().Where(b => b.UserId == userId);
        if (questionIds is not null)
        {
            bookmarks = bookmarks.Where(b => questionIds.Contains(b.QuestionId));
        }

        var totalCount = await bookmarks.CountAsync(cancellationToken);
        var items = await bookmarks
            .OrderByDescending(b => b.CreatedAt)
            .Skip((pageIndex - 1) * pageSize)
            .Take(pageSize)
            .Select(b => new BookmarkRow(b.QuestionId, b.CreatedAt))
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    public async Task<IReadOnlyList<Guid>> GetQuestionIdsAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await DbSet.AsNoTracking()
            .Where(b => b.UserId == userId)
            .Select(b => b.QuestionId)
            .ToListAsync(cancellationToken);
    }
}
