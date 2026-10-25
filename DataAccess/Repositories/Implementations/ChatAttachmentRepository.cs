using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class ChatAttachmentRepository : GenericRepository<ChatAttachment>, IChatAttachmentRepository
{
    public ChatAttachmentRepository(ChatAIWebDbContext context)
        : base(context)
    {
    }

    public Task<ChatAttachment?> GetOwnedAsync(
        Guid attachmentId,
        Guid userId,
        DateTime utcNow,
        CancellationToken cancellationToken = default)
    {
        return DbSet.FirstOrDefaultAsync(
            a => a.Id == attachmentId && a.UserId == userId && a.DeletedAt == null && a.ExpiresAt > utcNow,
            cancellationToken);
    }

    public async Task<IReadOnlyList<ChatAttachment>> GetOwnedInSessionAsync(
        IReadOnlyCollection<Guid> attachmentIds,
        Guid userId,
        Guid sessionId,
        DateTime utcNow,
        CancellationToken cancellationToken = default)
    {
        return await DbSet.AsNoTracking()
            .Where(a => attachmentIds.Contains(a.Id)
                && a.UserId == userId
                && a.SessionId == sessionId
                && a.DeletedAt == null
                && a.ExpiresAt > utcNow)
            .ToListAsync(cancellationToken);
    }

    public async Task<long> GetStoredBytesAsync(Guid userId, DateTime utcNow, CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(a => a.UserId == userId && a.DeletedAt == null && a.ExpiresAt > utcNow)
            .SumAsync(a => a.SizeBytes, cancellationToken);
    }

    public async Task<IReadOnlyList<ChatAttachment>> GetExpiredAsync(
        DateTime utcNow,
        int take,
        CancellationToken cancellationToken = default)
    {
        return await DbSet
            .Where(a => a.DeletedAt == null && a.ExpiresAt <= utcNow)
            .OrderBy(a => a.ExpiresAt)
            .Take(take)
            .ToListAsync(cancellationToken);
    }
}
