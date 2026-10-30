namespace BusinessLogic.Infrastructure.Settings;

public sealed class QuotaSettings
{
    public const string SectionName = "Quota";

    public bool RecoveryEnabled { get; set; } = true;

    public int RecoveryIntervalSeconds { get; set; } = 60;

    // Extra wait after a lease expires before recovery touches the turn, so a late completion is not raced.
    public int LeaseGraceSeconds { get; set; } = 30;

    // Completed turns still unsettled after this long are settled directly (the Worker may be down).
    public int SettleCompletedAfterMinutes { get; set; } = 15;

    public int RecoveryBatchSize { get; set; } = 100;

    // false: an expired turn with unknown usage releases its reservation; true: it is charged the reservation.
    public bool ChargeReservationWhenUsageUnknown { get; set; }
}
