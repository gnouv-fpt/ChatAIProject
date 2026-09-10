using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.Subject;

[Authorize(Roles = "Admin")]
public sealed class ImportMembersModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public ImportMembersModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    public async Task<IActionResult> OnPostAsync(
        int subjectId,
        IFormFile? file,
        CancellationToken cancellationToken)
    {
        if (file is null || file.Length == 0)
        {
            return CompleteRequest(false, "Vui lòng chọn file CSV/XLS/XLSX.", subjectId);
        }

        await using var stream = file.OpenReadStream();
        var result = await _subjectService.ImportSubjectMembersAsync(
            new ImportSubjectMembersRequestDto(subjectId, stream, file.FileName),
            cancellationToken);

        return CompleteRequest(result.Succeeded, result.Message, subjectId);
    }

    private IActionResult CompleteRequest(bool succeeded, string message, int subjectId)
    {
        if (IsAjaxRequest())
        {
            return new JsonResult(new { succeeded, message });
        }

        TempData[succeeded ? "SuccessMessage" : "ErrorMessage"] = message;
        return RedirectToPage("/Subject/Members", new { id = subjectId });
    }

    private bool IsAjaxRequest()
    {
        return string.Equals(
            Request.Headers["X-Requested-With"],
            "XMLHttpRequest",
            StringComparison.OrdinalIgnoreCase);
    }
}
