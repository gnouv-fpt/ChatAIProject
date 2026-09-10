using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.Document;

[Authorize(Roles = "Admin,Teacher")]
public sealed class RejectModel : AppPageModel
{
    private readonly IDocumentService _documentService;

    public RejectModel(IDocumentService documentService)
    {
        _documentService = documentService;
    }

    public async Task<IActionResult> OnPostAsync(
        int id,
        int? subjectId,
        string? reason,
        CancellationToken cancellationToken)
    {
        var result = await _documentService.RejectAsync(
            id,
            GetCurrentUserId(),
            GetCurrentUserRole(),
            reason,
            cancellationToken);

        if (Request.Headers.XRequestedWith == "XMLHttpRequest")
        {
            return new JsonResult(new
            {
                succeeded = result.Succeeded,
                message = result.Message,
                documentId = result.DocumentId
            });
        }

        TempData[result.Succeeded ? "SuccessMessage" : "ErrorMessage"] = result.Message;
        return RedirectToPage("/Document/Index", new { subjectId });
    }
}
