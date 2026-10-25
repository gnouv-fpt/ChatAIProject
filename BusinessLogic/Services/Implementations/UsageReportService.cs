using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class UsageReportService : IUsageReportService
{
    // Reports follow the Vietnam calendar day, matching the 00:00 Asia/Ho_Chi_Minh cron.
    private const int VietnamUtcOffsetHours = 7;
    private const int DefaultRangeDays = 30;
    private const int MaxRangeDays = 366;
    private const int TopUserCount = 10;

    private readonly IUsageReportRepository _reportRepository;
    private readonly IUserRepository _userRepository;
    private readonly IQuotaService _quotaService;

    public UsageReportService(
        IUsageReportRepository reportRepository,
        IUserRepository userRepository,
        IQuotaService quotaService)
    {
        _reportRepository = reportRepository;
        _userRepository = userRepository;
        _quotaService = quotaService;
    }

    public async Task<UsageReportDto> GetUsageAsync(
        Guid callerId,
        bool callerIsAdmin,
        UsageReportQueryDto query,
        CancellationToken cancellationToken = default)
    {
        Guid? scopeUserId;
        if (callerIsAdmin)
        {
            scopeUserId = query.UserId;
            if (scopeUserId is not null && await _userRepository.GetByIdAsync(scopeUserId.Value, cancellationToken) is null)
            {
                throw new NotFoundException("Không tìm thấy người dùng.");
            }
        }
        else
        {
            if (query.UserId is not null && query.UserId != callerId)
            {
                throw new ForbiddenException("Bạn chỉ được xem báo cáo sử dụng của chính mình.");
            }

            scopeUserId = callerId;
        }

        var today = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(VietnamUtcOffsetHours));
        var to = query.To ?? today;
        var from = query.From ?? to.AddDays(-(DefaultRangeDays - 1));
        if (from > to)
        {
            throw new BadRequestException("Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.");
        }

        if (to.DayNumber - from.DayNumber + 1 > MaxRangeDays)
        {
            throw new BadRequestException($"Khoảng thời gian báo cáo tối đa {MaxRangeDays} ngày.");
        }

        var fromUtc = ToUtcStart(from);
        var toUtc = ToUtcStart(to.AddDays(1));

        var totals = await _reportRepository.GetTotalsAsync(scopeUserId, fromUtc, toUtc, cancellationToken);
        var dailyRows = await _reportRepository.GetDailyAsync(scopeUserId, fromUtc, toUtc, VietnamUtcOffsetHours, cancellationToken);
        var byDate = dailyRows.ToDictionary(r => DateOnly.FromDateTime(r.Date));

        // Every day of the range is present so charts do not have gaps.
        var daily = new List<DailyUsageDto>();
        for (var date = from; date <= to; date = date.AddDays(1))
        {
            daily.Add(byDate.TryGetValue(date, out var row)
                ? new DailyUsageDto(date, row.CompletedTurns, row.ViolationTurns, row.TokensUsed)
                : new DailyUsageDto(date, 0, 0, 0));
        }

        var topUsers = scopeUserId is null
            ? (await _reportRepository.GetTopUsersAsync(fromUtc, toUtc, TopUserCount, cancellationToken))
                .Select(r => new UserUsageDto(r.UserId, r.Username, r.CompletedTurns, r.ViolationTurns, r.TokensUsed))
                .ToList()
            : new List<UserUsageDto>();

        var quota = scopeUserId is null ? null : await _quotaService.GetSnapshotAsync(scopeUserId.Value, cancellationToken);

        return new UsageReportDto(
            scopeUserId is null ? "All" : "User",
            scopeUserId,
            from,
            to,
            "UTC+07:00",
            new UsageTotalsDto(
                totals.CompletedTurns,
                totals.FailedTurns,
                totals.ViolationTurns,
                totals.TokensUsed,
                totals.TokensSettled,
                totals.UsageUnknownTurns,
                totals.ActiveUsers),
            daily,
            topUsers,
            quota);
    }

    private static DateTime ToUtcStart(DateOnly vietnamDate)
    {
        return DateTime.SpecifyKind(vietnamDate.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc).AddHours(-VietnamUtcOffsetHours);
    }
}
