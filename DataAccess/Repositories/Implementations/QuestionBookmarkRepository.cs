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
        Guid? bankId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var bookmarks = DbSet.AsNoTracking().Where(b => b.UserId == userId);
        if (bankId is not null)
        {
            bookmarks = bookmarks.Where(b => b.Question.BankId == bankId);
        }

        var totalCount = await bookmarks.CountAsync(cancellationToken);
        var items = await bookmarks
            .OrderByDescending(b => b.CreatedAt)
            .Skip((pageIndex - 1) * pageSize)
            .Take(pageSize)
            .Select(b => new BookmarkRow(
                b.QuestionId,
                b.Question.BankId,
                b.Question.Bank.Name,
                b.Question.Bank.Version,
                b.Question.Number,
                b.Question.Topic,
                b.Question.Content,
                b.Question.ImagePath != null,
                b.CreatedAt))
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    public async Task<IReadOnlyList<Guid>> GetQuestionIdsAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default)
    {
        return await DbSet.AsNoTracking()
            .Where(b => b.UserId == userId && b.Question.BankId == bankId)
            .Select(b => b.QuestionId)
            .ToListAsync(cancellationToken);
    }
}
