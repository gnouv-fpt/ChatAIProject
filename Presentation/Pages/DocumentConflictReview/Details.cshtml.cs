using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.DocumentConflictReview;

[Authorize(Roles = "Admin,Teacher")]
public sealed class DetailsModel : AppPageModel
{
    private readonly IDocumentConflictService _documentConflictService;

    public DetailsModel(IDocumentConflictService documentConflictService)
    {
        _documentConflictService = documentConflictService;
    }

    public DocumentConflictReviewDto? Review { get; private set; }

    public async Task<IActionResult> OnGetAsync(
        int? id,
        int? documentId,
        CancellationToken cancellationToken)
    {
        Review = id.HasValue
            ? await _documentConflictService.GetReviewAsync(
                id.Value,
                GetCurrentUserId(),
                GetCurrentUserRole(),
                cancellationToken)
            : documentId.HasValue
                ? await _documentConflictService.GetPendingReviewByDocumentIdAsync(
                    documentId.Value,
                    GetCurrentUserId(),
                    GetCurrentUserRole(),
                    cancellationToken)
                : null;

        if (Review is null)
        {
            return NotFound();
        }

        return Page();
    }

    public async Task<IActionResult> OnPostResolveAsync(
        int id,
        string resolutionChoice,
        string? note,
        CancellationToken cancellationToken)
    {
        var result = await _documentConflictService.ResolveAsync(
            id,
            resolutionChoice,
            GetCurrentUserId(),
            GetCurrentUserRole(),
            note,
            cancellationToken);

        TempData[result.Succeeded ? "SuccessMessage" : "ErrorMessage"] = result.Message;
        if (!result.Succeeded)
        {
            return RedirectToPage(new { id });
        }

        return RedirectToPage("/Document/Index");
    }
}
