using DataAccess.Models;

namespace DataAccess.Repositories.Interfaces;

public interface IUsageReportRepository
{
    // userId = null aggregates every user. Range is [fromUtc, toUtc).
    Task<UsageTotalsRow> GetTotalsAsync(
        Guid? userId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken = default);

    // Buckets by local calendar day: the UTC timestamp is shifted by utcOffsetHours before taking the date.
    Task<IReadOnlyList<DailyUsageRow>> GetDailyAsync(
        Guid? userId,
        DateTime fromUtc,
        DateTime toUtc,
        int utcOffsetHours,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<UserUsageRow>> GetTopUsersAsync(
        DateTime fromUtc,
        DateTime toUtc,
        int take,
        CancellationToken cancellationToken = default);
}
