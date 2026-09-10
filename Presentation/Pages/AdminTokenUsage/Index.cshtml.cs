using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Presentation.Models;

namespace Presentation.Pages.AdminTokenUsage;

[Authorize(Roles = "Admin")]
public sealed class IndexModel : AppPageModel
{
    private static readonly string[] ChartColors =
    {
        "#2563eb",
        "#16a34a",
        "#dc2626",
        "#9333ea",
        "#ea580c",
        "#0891b2",
        "#be123c",
        "#4f46e5"
    };

    private readonly ITokenUsageService _tokenUsageService;

    public IndexModel(ITokenUsageService tokenUsageService)
    {
        _tokenUsageService = tokenUsageService;
    }

    public AdminTokenUsageViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var usage = await _tokenUsageService.GetAdminUsageAsync(cancellationToken);
        var embeddingUsage = await _tokenUsageService.GetEmbeddingModelUsageAsync(cancellationToken);
        var dailyEmbeddingUsage = await _tokenUsageService.GetDailyEmbeddingModelUsageThisMonthAsync(cancellationToken);

        ViewModel = new AdminTokenUsageViewModel
        {
            Summary = MapSummary(usage.Summary),
            EmbeddingUsage = MapEmbeddingChart(embeddingUsage),
            DailyEmbeddingUsage = MapDailyEmbeddingChart(dailyEmbeddingUsage)
        };
    }

    private static TokenUsageSummaryViewModel MapSummary(TokenUsageSummaryDto usage)
    {
        return new TokenUsageSummaryViewModel
        {
            PromptTokens = usage.PromptTokens,
            CompletionTokens = usage.CompletionTokens,
            TotalTokens = usage.TotalTokens,
            AnswerCount = usage.AnswerCount,
            FirstUsedAt = usage.FirstUsedAt,
            LastUsedAt = usage.LastUsedAt
        };
    }

    private static EmbeddingTokenUsageChartViewModel MapEmbeddingChart(EmbeddingTokenUsageChartDto usage)
    {
        return new EmbeddingTokenUsageChartViewModel
        {
            Today = usage.Today.Select(MapEmbeddingModel).ToList(),
            ThisWeek = usage.ThisWeek.Select(MapEmbeddingModel).ToList(),
            ThisMonth = usage.ThisMonth.Select(MapEmbeddingModel).ToList()
        };
    }

    private static EmbeddingModelTokenUsageViewModel MapEmbeddingModel(EmbeddingModelTokenUsageDto usage)
    {
        return new EmbeddingModelTokenUsageViewModel
        {
            EmbeddingModel = usage.EmbeddingModel,
            TokenCount = usage.TokenCount,
            EmbeddingCount = usage.EmbeddingCount
        };
    }

    private static DailyEmbeddingTokenUsageChartViewModel MapDailyEmbeddingChart(
        IReadOnlyList<DailyEmbeddingModelTokenUsageDto> usage)
    {
        var today = DateTime.Now.Date;
        var monthStart = new DateTime(today.Year, today.Month, 1);
        var daysInMonth = DateTime.DaysInMonth(today.Year, today.Month);
        var days = Enumerable.Range(0, daysInMonth)
            .Select(offset => monthStart.AddDays(offset))
            .ToList();

        var usageByModel = usage
            .GroupBy(item => item.EmbeddingModel)
            .OrderByDescending(group => group.Sum(item => item.TokenCount))
            .ThenBy(group => group.Key, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var lookup = usage
            .GroupBy(item => (item.UsageDate.Date, item.EmbeddingModel))
            .ToDictionary(
                group => group.Key,
                group => group.Sum(item => item.TokenCount));

        var series = usageByModel.Select((group, index) => new DailyEmbeddingTokenUsageSeriesViewModel
        {
            EmbeddingModel = group.Key,
            Color = ChartColors[index % ChartColors.Length],
            Values = days.Select(day =>
                lookup.TryGetValue((day, group.Key), out var tokenCount) ? tokenCount : 0).ToList()
        }).ToList();

        return new DailyEmbeddingTokenUsageChartViewModel
        {
            Labels = days.Select(day => day.ToString("dd/MM")).ToList(),
            Series = series,
            MaxTokenCount = series.SelectMany(item => item.Values).DefaultIfEmpty(0).Max()
        };
    }
}
