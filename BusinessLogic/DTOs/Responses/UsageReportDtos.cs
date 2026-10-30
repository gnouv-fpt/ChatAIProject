namespace BusinessLogic.DTOs.Responses;

public sealed record UsageReportDto(
    string Scope,
    Guid? UserId,
    DateOnly From,
    DateOnly To,
    string TimeZone,
    UsageTotalsDto Totals,
    IReadOnlyList<DailyUsageDto> Daily,
    IReadOnlyList<UserUsageDto> TopUsers,
    QuotaSnapshotDto? Quota);

// One turn = one question answered by the assistant; user prompts are not counted on top of it.
public sealed record UsageTotalsDto(
    int CompletedTurns,
    int FailedTurns,
    int ViolationTurns,
    long TokensUsed,
    long TokensSettled,
    int UsageUnknownTurns,
    int ActiveUsers);

public sealed record DailyUsageDto(DateOnly Date, int CompletedTurns, int ViolationTurns, long TokensUsed);

public sealed record UserUsageDto(Guid UserId, string Username, int CompletedTurns, int ViolationTurns, long TokensUsed);
