using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Subject;

[Authorize(Roles = "Admin")]
public sealed class AddMemberModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public AddMemberModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    public async Task<IActionResult> OnPostAsync(
        int subjectId,
        AddSubjectMemberViewModel addMember,
        CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return CompleteRequest(
                false,
                "Vui lòng chọn người dùng và role hợp lệ.",
                subjectId);
        }

        var result = await _subjectService.AddSubjectMemberAsync(
            new AddSubjectMemberRequestDto(subjectId, addMember.UserId, addMember.RoleInClass),
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
