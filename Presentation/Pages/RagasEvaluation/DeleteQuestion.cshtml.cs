using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class DeleteQuestionModel : AppPageModel
{
    private readonly IRagasEvaluationService _evaluationService;

    public DeleteQuestionModel(IRagasEvaluationService evaluationService)
    {
        _evaluationService = evaluationService;
    }

    public async Task<IActionResult> OnPostAsync(int id, int subjectId, CancellationToken cancellationToken)
    {
        await _evaluationService.DeleteQuestionAsync(id, cancellationToken);
        return RedirectToPage("/RagasEvaluation/Questions", new { subjectId });
    }
}
