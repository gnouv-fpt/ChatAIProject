using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Presentation.Models;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class IndexModel : AppPageModel
{
    private readonly IRagasEvaluationService _evaluationService;

    public IndexModel(IRagasEvaluationService evaluationService)
    {
        _evaluationService = evaluationService;
    }

    public RagasSubjectListViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var summaries = await _evaluationService.GetSubjectSummariesAsync(cancellationToken);
        ViewModel = new RagasSubjectListViewModel
        {
            Subjects = summaries
                .OrderByDescending(summary => summary.BenchmarkRunCount > 0)
                .ThenByDescending(summary => summary.LastRunDate)
                .ThenBy(summary => summary.SubjectCode)
                .Select(summary => new RagasSubjectItem
                {
                    SubjectId = summary.SubjectId,
                    SubjectCode = summary.SubjectCode,
                    SubjectName = summary.SubjectName,
                    QuestionCount = summary.QuestionCount,
                    BenchmarkRunCount = summary.BenchmarkRunCount,
                    LastRecallAt5 = summary.LastRecallAt5,
                    LastRunDate = summary.LastRunDate
                })
                .ToList()
        };
    }
}
