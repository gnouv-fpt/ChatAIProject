namespace BusinessLogic.DTOs.Responses;

public sealed record QuotaSnapshotDto(
    int TokenQuota,
    int TokenBalance,
    long ReservedTokens,
    long AvailableTokens);

public enum QuotaSettlementStatus
{
    Settled,
    AlreadySettled,
    NotCompleted,
    NotFound
}

public sealed record QuotaSettlementResultDto(
    QuotaSettlementStatus Status,
    int TokensCharged,
    int BalanceAfter);

public sealed record QuotaRecoveryResultDto(
    int ExpiredReservationsReleased,
    int ExpiredReservationsCharged,
    int CompletedTurnsSettled);
