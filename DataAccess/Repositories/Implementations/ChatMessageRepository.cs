using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class ChatMessageRepository : GenericRepository<ChatMessage>, IChatMessageRepository
{
    public ChatMessageRepository(ChatAIWebDbContext context)
        : base(context)
    {
    }

    public async Task<IReadOnlyList<ChatMessage>> GetMessagesBySessionIdAsync(Guid sessionId, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .AsNoTracking()
            .Include(m => m.Citations)
            .Where(m => m.SessionId == sessionId)
            .OrderBy(m => m.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public Task<ChatMessage?> GetMessageWithCitationsAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return DbSet
            .Include(m => m.Citations)
            .FirstOrDefaultAsync(m => m.Id == messageId, cancellationToken);
    }
}
