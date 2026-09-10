using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.Document;

[Authorize(Roles = "Admin,Teacher")]
public sealed class VerifyModel : AppPageModel
{
    private readonly IDocumentService _documentService;

    public VerifyModel(IDocumentService documentService)
    {
        _documentService = documentService;
    }

    public async Task<IActionResult> OnPostAsync(int id, int? subjectId, CancellationToken cancellationToken)
    {
        var result = await _documentService.VerifyAndIndexAsync(
            id,
            GetCurrentUserId(),
            GetCurrentUserRole(),
            CancellationToken.None);

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
