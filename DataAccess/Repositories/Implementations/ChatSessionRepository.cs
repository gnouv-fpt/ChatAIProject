using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class ChatSessionRepository : GenericRepository<ChatSession>, IChatSessionRepository
{
    public ChatSessionRepository(ChatAIWebDbContext context)
        : base(context)
    {
    }

    public Task<ChatSession?> GetSessionWithMessagesAsync(Guid sessionId, Guid userId, CancellationToken cancellationToken = default)
    {
        return DbSet
            .Include(s => s.Messages.OrderBy(m => m.CreatedAt))
                .ThenInclude(m => m.Citations)
            .FirstOrDefaultAsync(s => s.Id == sessionId && s.UserId == userId && !s.IsDeleted, cancellationToken);
    }

    public async Task<(IReadOnlyList<ChatSession> Items, int TotalCount)> GetUserSessionsPagedAsync(
        Guid userId,
        int pageIndex,
        int pageSize,
        string? search = null,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet.AsNoTracking().Where(s => s.UserId == userId && !s.IsDeleted);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var searchTrimmed = search.Trim().ToLower();
            query = query.Where(s => s.Title.ToLower().Contains(searchTrimmed));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderByDescending(s => s.LastUpdatedAt)
            .Skip((pageIndex - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    public async Task<bool> SoftDeleteSessionAsync(Guid sessionId, Guid userId, CancellationToken cancellationToken = default)
    {
        var session = await DbSet.FirstOrDefaultAsync(s => s.Id == sessionId && s.UserId == userId && !s.IsDeleted, cancellationToken);
        if (session == null)
        {
            return false;
        }

        session.IsDeleted = true;
        session.LastUpdatedAt = DateTime.UtcNow;
        return true;
    }
}
