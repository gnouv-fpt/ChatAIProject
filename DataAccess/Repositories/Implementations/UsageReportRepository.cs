using BusinessObject.Constants;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Models;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class UsageReportRepository : IUsageReportRepository
{
    private readonly ChatAIWebDbContext _context;

    public UsageReportRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public async Task<UsageTotalsRow> GetTotalsAsync(
        Guid? userId,
        DateTime fromUtc,
        DateTime toUtc,
        CancellationToken cancellationToken = default)
    {
        var turns = Turns(userId, fromUtc, toUtc);

        var totals = await turns
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Completed = g.Count(m => m.TurnState == null || m.TurnState == ChatTurnStates.Completed),
                Failed = g.Count(m => m.TurnState == ChatTurnStates.Failed),
                Violations = g.Count(m => (m.TurnState == null || m.TurnState == ChatTurnStates.Completed) && m.IsViolation),
                Tokens = g.Sum(m => m.TurnState == null || m.TurnState == ChatTurnStates.Completed ? (long)m.TokensUsed : 0L),
                Settled = g.Sum(m => m.QuotaSettledAt != null ? (long)m.TokensUsed : 0L),
                Unknown = g.Count(m => m.ResultStatus == ChatResultStatuses.UsageUnknown)
            })
            .FirstOrDefaultAsync(cancellationToken);

        var activeUsers = await turns.Select(m => m.Session.UserId).Distinct().CountAsync(cancellationToken);

        return totals is null
            ? new UsageTotalsRow(0, 0, 0, 0, 0, 0, 0)
            : new UsageTotalsRow(totals.Completed, totals.Failed, totals.Violations, totals.Tokens, totals.Settled, totals.Unknown, activeUsers);
    }

    public async Task<IReadOnlyList<DailyUsageRow>> GetDailyAsync(
        Guid? userId,
        DateTime fromUtc,
        DateTime toUtc,
        int utcOffsetHours,
        CancellationToken cancellationToken = default)
    {
        var rows = await CompletedTurns(userId, fromUtc, toUtc)
            .GroupBy(m => m.CreatedAt.AddHours(utcOffsetHours).Date)
            .Select(g => new
            {
                Date = g.Key,
                Completed = g.Count(),
                Violations = g.Count(m => m.IsViolation),
                Tokens = g.Sum(m => (long)m.TokensUsed)
            })
            .OrderBy(r => r.Date)
            .ToListAsync(cancellationToken);

        return rows.Select(r => new DailyUsageRow(DateTime.SpecifyKind(r.Date, DateTimeKind.Unspecified), r.Completed, r.Violations, r.Tokens)).ToList();
    }

    public async Task<IReadOnlyList<UserUsageRow>> GetTopUsersAsync(
        DateTime fromUtc,
        DateTime toUtc,
        int take,
        CancellationToken cancellationToken = default)
    {
        var rows = await CompletedTurns(null, fromUtc, toUtc)
            .GroupBy(m => m.Session.UserId)
            .Select(g => new
            {
                UserId = g.Key,
                Completed = g.Count(),
                Violations = g.Count(m => m.IsViolation),
                Tokens = g.Sum(m => (long)m.TokensUsed)
            })
            .OrderByDescending(r => r.Tokens)
            .ThenByDescending(r => r.Completed)
            .Take(take)
            .ToListAsync(cancellationToken);

        var userIds = rows.Select(r => r.UserId).ToList();
        var names = await _context.Users
            .Where(u => userIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.Username, cancellationToken);

        return rows
            .Select(r => new UserUsageRow(r.UserId, names.GetValueOrDefault(r.UserId, string.Empty), r.Completed, r.Violations, r.Tokens))
            .ToList();
    }

    // A turn is one assistant message; counting it instead of user prompts avoids double counting.
    private IQueryable<ChatMessage> Turns(Guid? userId, DateTime fromUtc, DateTime toUtc)
    {
        var query = _context.ChatMessages.AsNoTracking()
            .Where(m => m.SenderRole == SenderRole.Assistant && m.CreatedAt >= fromUtc && m.CreatedAt < toUtc);

        return userId is null ? query : query.Where(m => m.Session.UserId == userId);
    }

    private IQueryable<ChatMessage> CompletedTurns(Guid? userId, DateTime fromUtc, DateTime toUtc)
    {
        return Turns(userId, fromUtc, toUtc)
            .Where(m => m.TurnState == null || m.TurnState == ChatTurnStates.Completed);
    }
}
