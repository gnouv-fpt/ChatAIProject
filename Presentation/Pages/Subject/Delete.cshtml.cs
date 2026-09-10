using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.Subject;

[Authorize(Roles = "Admin")]
public sealed class DeleteModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public DeleteModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    public async Task<IActionResult> OnPostAsync(
        int id,
        string? reason,
        string? statusFilter,
        CancellationToken cancellationToken)
    {
        var result = await _subjectService.DeleteSubjectAsync(id, GetCurrentUserId(), reason, cancellationToken);
        if (IsAjaxRequest())
        {
            return new JsonResult(new { succeeded = result.Succeeded, message = result.Message });
        }

        TempData[result.Succeeded ? "SuccessMessage" : "ErrorMessage"] = result.Message;
        return RedirectToPage("/Subject/Index", new { statusFilter });
    }

    private bool IsAjaxRequest()
    {
        return string.Equals(
            Request.Headers["X-Requested-With"],
            "XMLHttpRequest",
            StringComparison.OrdinalIgnoreCase);
    }
}
