using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Presentation.Models;

namespace Presentation.Pages.TokenUsage;

[Authorize]
public sealed class IndexModel : AppPageModel
{
    private readonly ITokenUsageService _tokenUsageService;

    public IndexModel(ITokenUsageService tokenUsageService)
    {
        _tokenUsageService = tokenUsageService;
    }

    public TokenUsageSummaryViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var usage = await _tokenUsageService.GetUserUsageAsync(GetCurrentUserId(), cancellationToken);
        ViewModel = MapSummary(usage);
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
}
