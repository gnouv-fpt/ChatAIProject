using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Presentation.Models;

namespace Presentation.Pages.Subject;

[Authorize(Roles = "Admin")]
public sealed class MembersModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public MembersModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    public SubjectMembersViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(int id, CancellationToken cancellationToken)
    {
        var viewModel = await LoadViewModelAsync(id, cancellationToken);
        if (viewModel is null)
        {
            return NotFound("Không tìm thấy môn học.");
        }

        ViewModel = viewModel;
        return Page();
    }

    public async Task<IActionResult> OnGetMembersPartialAsync(int id, CancellationToken cancellationToken)
    {
        var viewModel = await LoadViewModelAsync(id, cancellationToken);
        if (viewModel is null)
        {
            return NotFound("Không tìm thấy môn học.");
        }

        ViewModel = viewModel;
        return new PartialViewResult
        {
            ViewName = "/Pages/Subject/_SubjectMembersPartial.cshtml",
            ViewData = new ViewDataDictionary<SubjectMembersViewModel>(ViewData, ViewModel)
        };
    }

    private async Task<SubjectMembersViewModel?> LoadViewModelAsync(
        int id,
        CancellationToken cancellationToken)
    {
        var members = await _subjectService.GetSubjectMembersAsync(id, cancellationToken);
        return members is null ? null : MapMembers(members);
    }

    private static SubjectMembersViewModel MapMembers(SubjectMembersDto dto)
    {
        return new SubjectMembersViewModel
        {
            SubjectId = dto.SubjectId,
            SubjectCode = dto.SubjectCode,
            SubjectName = dto.SubjectName,
            HeadTeacherId = dto.HeadTeacherId,
            HeadTeacherName = dto.HeadTeacherName,
            Members = dto.Members.Select(member => new SubjectMemberViewModel
            {
                EnrollmentId = member.EnrollmentId,
                UserId = member.UserId,
                FullName = member.FullName,
                Email = member.Email,
                RoleInClass = member.RoleInClass,
                EnrolledAt = member.EnrolledAt,
                IsHeadTeacher = member.IsHeadTeacher
            }).ToList(),
            Candidates = dto.Candidates.Select(candidate => new SubjectMemberCandidateViewModel
            {
                UserId = candidate.UserId,
                FullName = candidate.FullName,
                Email = candidate.Email,
                Role = candidate.Role
            }).ToList()
        };
    }
}
