using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ViewFeatures;
using Presentation.Models;

namespace Presentation.Pages.Subject;

[Authorize(Roles = "Admin,Teacher")]
public sealed class IndexModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public IndexModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    public SubjectPageViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(string? statusFilter, CancellationToken cancellationToken)
    {
        ViewModel = await LoadViewModelAsync(statusFilter, cancellationToken);
    }

    public async Task<IActionResult> OnGetListPartialAsync(string? statusFilter, CancellationToken cancellationToken)
    {
        ViewModel = await LoadViewModelAsync(statusFilter, cancellationToken);
        return new PartialViewResult
        {
            ViewName = "/Pages/Subject/_SubjectListPartial.cshtml",
            ViewData = new ViewDataDictionary<SubjectPageViewModel>(ViewData, ViewModel)
        };
    }

    private async Task<SubjectPageViewModel> LoadViewModelAsync(string? statusFilter, CancellationToken cancellationToken)
    {
        var normalizedStatusFilter = NormalizeStatusFilter(statusFilter);
        var subjects = await _subjectService.GetManagementSubjectsAsync(
            GetCurrentUserId(),
            GetCurrentUserRole(),
            normalizedStatusFilter,
            cancellationToken);

        return new SubjectPageViewModel
        {
            IsAdmin = User.IsInRole("Admin"),
            StatusFilter = normalizedStatusFilter,
            Subjects = subjects.Select(MapSubject).ToList()
        };
    }

    private static string NormalizeStatusFilter(string? statusFilter)
    {
        return statusFilter is "deleted" or "all" ? statusFilter : "active";
    }

    private static SubjectViewModel MapSubject(SubjectDto s)
    {
        return new SubjectViewModel
        {
            Id = s.Id,
            SubjectCode = s.SubjectCode,
            SubjectName = s.SubjectName,
            Description = s.Description,
            DocumentCount = s.DocumentCount,
            IndexedDocumentCount = s.IndexedDocumentCount,
            StudentCount = s.StudentCount,
            TeacherCount = s.TeacherCount,
            CreatedAt = s.CreatedAt,
            CreatedById = s.CreatedById,
            CreatedByName = s.CreatedByName,
            IsTeacherEnrolled = s.IsTeacherEnrolled,
            CanManage = s.CanManage,
            IsDeleted = s.IsDeleted,
            DeletedAt = s.DeletedAt,
            DeleteReason = s.DeleteReason,
            TeacherNames = s.TeacherNames,
            MemberNames = s.MemberNames
        };
    }
}
