namespace DataAccess.Models;

// Aggregated over chat turns (assistant messages); user prompts are never counted separately.
public sealed record UsageTotalsRow(
    int CompletedTurns,
    int FailedTurns,
    int ViolationTurns,
    long TokensUsed,
    long TokensSettled,
    int UsageUnknownTurns,
    int ActiveUsers);

public sealed record DailyUsageRow(DateTime Date, int CompletedTurns, int ViolationTurns, long TokensUsed);

public sealed record UserUsageRow(Guid UserId, string Username, int CompletedTurns, int ViolationTurns, long TokensUsed);
