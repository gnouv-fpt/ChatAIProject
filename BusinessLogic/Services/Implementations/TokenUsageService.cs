using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Interfaces;
using DataAccess.Repositories.Models;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class TokenUsageService : ITokenUsageService
{
    private readonly IChatRepository _chatRepository;
    private readonly IDocumentChunkEmbeddingRepository _embeddingRepository;
    private readonly ILogger<TokenUsageService> _logger;

    public TokenUsageService(
        IChatRepository chatRepository,
        IDocumentChunkEmbeddingRepository embeddingRepository,
        ILogger<TokenUsageService> logger)
    {
        _chatRepository = chatRepository;
        _embeddingRepository = embeddingRepository;
        _logger = logger;
    }

    public async Task<TokenUsageSummaryDto> GetUserUsageAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            return MapSummary(await _chatRepository.GetTokenUsageByUserAsync(userId, cancellationToken));
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Failed to load token usage for user {UserId}", userId);
            throw;
        }
    }

    public async Task<AdminTokenUsageDto> GetAdminUsageAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var summary = await _chatRepository.GetTokenUsageAsync(cancellationToken);
            var users = await _chatRepository.GetTokenUsageByUsersAsync(cancellationToken);

            return new AdminTokenUsageDto(
                MapSummary(summary),
                users.Select(MapUser).ToList());
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Failed to load admin token usage");
            throw;
        }
    }

    public async Task<EmbeddingTokenUsageChartDto> GetEmbeddingModelUsageAsync(
        CancellationToken cancellationToken = default)
    {
        try
        {
            var now = DateTime.Now;
            var todayStart = now.Date;
            var tomorrowStart = todayStart.AddDays(1);
            var daysSinceMonday = ((int)todayStart.DayOfWeek - (int)DayOfWeek.Monday + 7) % 7;
            var weekStart = todayStart.AddDays(-daysSinceMonday);
            var nextWeekStart = weekStart.AddDays(7);
            var monthStart = new DateTime(todayStart.Year, todayStart.Month, 1);
            var nextMonthStart = monthStart.AddMonths(1);

            var today = await GetEmbeddingUsageAsync(todayStart, tomorrowStart, cancellationToken);
            var thisWeek = await GetEmbeddingUsageAsync(weekStart, nextWeekStart, cancellationToken);
            var thisMonth = await GetEmbeddingUsageAsync(monthStart, nextMonthStart, cancellationToken);

            return new EmbeddingTokenUsageChartDto(today, thisWeek, thisMonth);
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Failed to load embedding token usage");
            throw;
        }
    }

    public async Task<IReadOnlyList<DailyEmbeddingModelTokenUsageDto>> GetDailyEmbeddingModelUsageThisMonthAsync(
        CancellationToken cancellationToken = default)
    {
        try
        {
            var now = DateTime.Now;
            var monthStart = new DateTime(now.Year, now.Month, 1);
            var nextMonthStart = monthStart.AddMonths(1);
            var startUtc = DateTime.SpecifyKind(monthStart, DateTimeKind.Local).ToUniversalTime();
            var endUtc = DateTime.SpecifyKind(nextMonthStart, DateTimeKind.Local).ToUniversalTime();

            var usage = await _embeddingRepository.GetDailyTokenUsageByModelAsync(
                startUtc,
                endUtc,
                cancellationToken);

            return usage
                .Select(item => new DailyEmbeddingModelTokenUsageDto(
                    item.UsageDate.Date,
                    item.EmbeddingModel,
                    item.TokenCount))
                .ToList();
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Failed to load daily embedding token usage");
            throw;
        }
    }

    private async Task<IReadOnlyList<EmbeddingModelTokenUsageDto>> GetEmbeddingUsageAsync(
        DateTime localStartInclusive,
        DateTime localEndExclusive,
        CancellationToken cancellationToken)
    {
        var startUtc = DateTime.SpecifyKind(localStartInclusive, DateTimeKind.Local).ToUniversalTime();
        var endUtc = DateTime.SpecifyKind(localEndExclusive, DateTimeKind.Local).ToUniversalTime();
        var usage = await _embeddingRepository.GetTokenUsageByModelAsync(startUtc, endUtc, cancellationToken);
        return usage.Select(MapEmbeddingUsage).ToList();
    }

    private static TokenUsageSummaryDto MapSummary(TokenUsageAggregate usage)
    {
        return new TokenUsageSummaryDto(
            usage.PromptTokens,
            usage.CompletionTokens,
            usage.TotalTokens,
            usage.AnswerCount,
            usage.FirstUsedAt,
            usage.LastUsedAt);
    }

    private static UserTokenUsageDto MapUser(UserTokenUsageAggregate usage)
    {
        return new UserTokenUsageDto(
            usage.UserId,
            usage.FullName,
            usage.Email,
            usage.Role,
            usage.PromptTokens,
            usage.CompletionTokens,
            usage.TotalTokens,
            usage.AnswerCount,
            usage.LastUsedAt);
    }

    private static EmbeddingModelTokenUsageDto MapEmbeddingUsage(EmbeddingModelTokenUsageAggregate usage)
    {
        return new EmbeddingModelTokenUsageDto(
            usage.EmbeddingModel,
            usage.TokenCount,
            usage.EmbeddingCount);
    }
}
