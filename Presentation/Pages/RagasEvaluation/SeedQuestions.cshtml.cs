using System.Security.Claims;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class SeedQuestionsModel : AppPageModel
{
    private readonly IRagasEvaluationService _evaluationService;

    public SeedQuestionsModel(IRagasEvaluationService evaluationService)
    {
        _evaluationService = evaluationService;
    }

    public async Task<IActionResult> OnPostAsync(int subjectId, CancellationToken cancellationToken)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        await _evaluationService.SeedQuestionsAsync(subjectId, userId, cancellationToken);
        return RedirectToPage("/RagasEvaluation/Questions", new { subjectId });
    }
}
