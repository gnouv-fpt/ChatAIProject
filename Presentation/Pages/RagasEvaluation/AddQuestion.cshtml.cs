using System.Security.Claims;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class AddQuestionModel : AppPageModel
{
    private readonly IRagasEvaluationService _evaluationService;

    public AddQuestionModel(IRagasEvaluationService evaluationService)
    {
        _evaluationService = evaluationService;
    }

    public async Task<IActionResult> OnPostAsync(
        RagasAddQuestionViewModel model,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var result = await _evaluationService.AddQuestionAsync(
            model.SubjectId,
            model.Question,
            model.GroundTruthAnswer,
            userId,
            cancellationToken);

        if (!result.Success || !result.QuestionId.HasValue)
        {
            TempData["ErrorMessage"] = result.Message;
            return RedirectToPage("/RagasEvaluation/Questions", new { subjectId = model.SubjectId });
        }

        TempData["SuccessMessage"] = result.Message;
        return RedirectToPage("/RagasEvaluation/QuestionSetup", new { id = result.QuestionId.Value });
    }
}
