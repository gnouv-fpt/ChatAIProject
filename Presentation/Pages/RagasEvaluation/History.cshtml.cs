using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class HistoryModel : AppPageModel
{
    private const int PageSize = 20;
    private readonly IRagasEvaluationService _evaluationService;

    public HistoryModel(IRagasEvaluationService evaluationService)
    {
        _evaluationService = evaluationService;
    }

    public RagasRunHistoryViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(
        int subjectId,
        int pageNumber = 1,
        CancellationToken cancellationToken = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        var history = await _evaluationService.GetRunHistoryAsync(
            subjectId,
            pageNumber,
            PageSize,
            cancellationToken);

        if (history is null)
        {
            return RedirectToPage("/RagasEvaluation/Index");
        }

        var totalPages = Math.Max(1, (int)Math.Ceiling(history.TotalRuns / (double)history.PageSize));
        if (history.TotalRuns > 0 && pageNumber > totalPages)
        {
            return RedirectToPage(new
            {
                subjectId,
                pageNumber = totalPages
            });
        }

        ViewModel = new RagasRunHistoryViewModel
        {
            SubjectId = history.SubjectId,
            SubjectName = history.SubjectName,
            PageNumber = history.PageNumber,
            PageSize = history.PageSize,
            TotalRuns = history.TotalRuns,
            Items = history.Items.Select(item => new RagasRunHistoryItemViewModel
            {
                RunId = item.RunId,
                RunDate = item.RunDate,
                EmbeddingModels = item.EmbeddingModels.ToList(),
                ChunkingStrategies = item.ChunkingStrategies.ToList(),
                QuestionCount = item.QuestionCount,
                AvgRecallAt5 = item.AvgRecallAt5
            }).ToList()
        };

        return Page();
    }
}
