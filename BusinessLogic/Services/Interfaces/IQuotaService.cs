using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

// Token budget for chat turns. A turn is the assistant ChatMessage keyed by RequestId.
// Each call is its own short transaction; never call these while holding a transaction across the AI call.
public interface IQuotaService
{
    Task<QuotaSnapshotDto> GetSnapshotAsync(Guid userId, CancellationToken cancellationToken = default);

    // The turn must already exist in Processing state. Returns the reserved amount (at most requestedTokens).
    // Throws QuotaExceededException (429) when nothing is available.
    Task<int> ReserveAsync(
        Guid userId,
        Guid messageId,
        int requestedTokens,
        TimeSpan lease,
        CancellationToken cancellationToken = default);

    // Gives the budget back when the AI call failed. leaseId fences a stale caller; returns false if nothing changed.
    Task<bool> ReleaseAsync(Guid messageId, Guid? leaseId, CancellationToken cancellationToken = default);

    // Deducts the turn's TokensUsed from TokenBalance exactly once, however many times the event is delivered.
    Task<QuotaSettlementResultDto> SettleAsync(Guid messageId, Guid eventId, CancellationToken cancellationToken = default);

    // Frees expired reservations and settles completed turns whose event never arrived.
    Task<QuotaRecoveryResultDto> RecoverAsync(CancellationToken cancellationToken = default);
}
