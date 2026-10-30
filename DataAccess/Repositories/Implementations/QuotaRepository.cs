using BusinessObject.Constants;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class QuotaRepository : IQuotaRepository
{
    private readonly ChatAIWebDbContext _context;

    public QuotaRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public Task<T> ExecuteWithUserLockAsync<T>(
        Guid userId,
        Func<User?, Task<T>> operation,
        CancellationToken cancellationToken = default)
    {
        return _context.Database.CreateExecutionStrategy().ExecuteAsync(async () =>
        {
            _context.ChangeTracker.Clear();
            await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
            // UPDLOCK is held until commit, so reserve/settle/release of one user run one at a time,
            // while the AI call itself happens outside any transaction.
            var user = _context.Database.IsSqlServer()
                ? await _context.Users
                    .FromSqlInterpolated($"SELECT * FROM [Users] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {userId}")
                    .SingleOrDefaultAsync(cancellationToken)
                : await _context.Users.SingleOrDefaultAsync(u => u.Id == userId, cancellationToken);
            var result = await operation(user);
            await _context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return result;
        });
    }

    public async Task<long> GetHeldTokensAsync(
        Guid userId,
        Guid? excludeMessageId,
        DateTime utcNow,
        CancellationToken cancellationToken = default)
    {
        return await _context.ChatMessages
            .Where(m => m.Session.UserId == userId
                && m.Id != excludeMessageId
                && m.QuotaSettledAt == null
                && m.ReservedTokens > 0
                && (m.TurnState == ChatTurnStates.Completed
                    || (m.TurnState == ChatTurnStates.Processing && m.LeaseExpiresAt > utcNow)))
            .SumAsync(m => (long)m.ReservedTokens, cancellationToken);
    }

    public Task<ChatMessage?> GetTurnAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return _context.ChatMessages.FirstOrDefaultAsync(m => m.Id == messageId, cancellationToken);
    }

    public async Task<Guid?> GetTurnOwnerIdAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return await _context.ChatMessages
            .Where(m => m.Id == messageId && m.SenderRole == SenderRole.Assistant)
            .Select(m => (Guid?)m.Session.UserId)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Guid>> GetExpiredReservationIdsAsync(
        DateTime leaseExpiredBefore,
        int take,
        CancellationToken cancellationToken = default)
    {
        return await _context.ChatMessages
            .Where(m => m.TurnState == ChatTurnStates.Processing
                && m.QuotaSettledAt == null
                && m.LeaseExpiresAt != null
                && m.LeaseExpiresAt < leaseExpiredBefore)
            .OrderBy(m => m.LeaseExpiresAt)
            .Select(m => m.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Guid>> GetUnsettledCompletedTurnIdsAsync(
        DateTime completedBefore,
        int take,
        CancellationToken cancellationToken = default)
    {
        return await _context.ChatMessages
            .Where(m => m.TurnState == ChatTurnStates.Completed
                && m.QuotaSettledAt == null
                && m.CreatedAt < completedBefore)
            .OrderBy(m => m.CreatedAt)
            .Select(m => m.Id)
            .Take(take)
            .ToListAsync(cancellationToken);
    }
}
