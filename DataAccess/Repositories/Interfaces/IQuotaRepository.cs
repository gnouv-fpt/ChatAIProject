using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IQuotaRepository
{
    // Short transaction holding an update lock on the user row; every quota change of one user is serialized by it.
    // The operation receives null when the user does not exist. Changes are saved and committed on return.
    Task<T> ExecuteWithUserLockAsync<T>(
        Guid userId,
        Func<User?, Task<T>> operation,
        CancellationToken cancellationToken = default);

    // Sum of ReservedTokens of turns that are not settled and still hold budget at utcNow.
    Task<long> GetHeldTokensAsync(
        Guid userId,
        Guid? excludeMessageId,
        DateTime utcNow,
        CancellationToken cancellationToken = default);

    Task<ChatMessage?> GetTurnAsync(Guid messageId, CancellationToken cancellationToken = default);

    Task<Guid?> GetTurnOwnerIdAsync(Guid messageId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Guid>> GetExpiredReservationIdsAsync(
        DateTime leaseExpiredBefore,
        int take,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Guid>> GetUnsettledCompletedTurnIdsAsync(
        DateTime completedBefore,
        int take,
        CancellationToken cancellationToken = default);
}
