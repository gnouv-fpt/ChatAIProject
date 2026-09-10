using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.Dashboard;

[Authorize(Roles = "Student")]
public sealed class JoinSubjectModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public JoinSubjectModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    public async Task<IActionResult> OnPostAsync(int subjectId, CancellationToken cancellationToken)
    {
        var result = await _subjectService.EnrollStudentAsync(
            subjectId,
            GetCurrentUserId(),
            cancellationToken);

        TempData[result.Succeeded ? "SuccessMessage" : "ErrorMessage"] = result.Message;
        return RedirectToPage("/Dashboard/SelectSubject");
    }
}
