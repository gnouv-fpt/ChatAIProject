using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Subject;

[Authorize(Roles = "Admin")]
public sealed class CreateModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public CreateModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    [BindProperty]
    public CreateSubjectViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        ViewModel.TeacherOptions = await GetTeacherOptionsAsync(cancellationToken);
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            ViewModel.TeacherOptions = await GetTeacherOptionsAsync(cancellationToken);
            return Page();
        }

        var result = await _subjectService.CreateSubjectAsync(
            new CreateSubjectRequestDto(
                ViewModel.SubjectCode,
                ViewModel.SubjectName,
                ViewModel.Description,
                GetCurrentUserId(),
                GetCurrentUserRole(),
                ViewModel.HeadTeacherId),
            cancellationToken);

        if (!result.Succeeded)
        {
            ModelState.AddModelError(string.Empty, result.Message);
            ViewModel.TeacherOptions = await GetTeacherOptionsAsync(cancellationToken);
            return Page();
        }

        TempData["SuccessMessage"] = result.Message;
        return RedirectToPage("/Subject/Index");
    }

    private async Task<IReadOnlyList<SubjectMemberCandidateViewModel>> GetTeacherOptionsAsync(
        CancellationToken cancellationToken)
    {
        var candidates = await _subjectService.GetMemberCandidatesAsync(cancellationToken);
        return candidates
            .Where(candidate => string.Equals(candidate.Role, "Teacher", StringComparison.OrdinalIgnoreCase))
            .Select(MapCandidate)
            .ToList();
    }

    private static SubjectMemberCandidateViewModel MapCandidate(SubjectMemberCandidateDto candidate)
    {
        return new SubjectMemberCandidateViewModel
        {
            UserId = candidate.UserId,
            FullName = candidate.FullName,
            Email = candidate.Email,
            Role = candidate.Role
        };
    }
}
