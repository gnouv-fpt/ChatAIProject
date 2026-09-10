using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Dashboard;

[Authorize]
public sealed class SelectSubjectModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public SelectSubjectModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    public SelectSubjectViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(string? filter, CancellationToken cancellationToken)
    {
        var subjects = await _subjectService.GetSelectableSubjectsAsync(
            GetCurrentUserId(),
            GetCurrentUserRole(),
            null,
            cancellationToken);

        ViewModel = new SelectSubjectViewModel
        {
            SelectedFilter = User.IsInRole("Teacher") ? "enrolled" : "all",
            ShowTeacherFilters = false,
            Subjects = subjects
                .Select(s => new SubjectSelectionItemViewModel
                {
                    Id = s.Id,
                    SubjectCode = s.SubjectCode,
                    SubjectName = s.SubjectName,
                    Description = s.Description,
                    IndexedDocumentCount = s.IndexedDocumentCount,
                    IsEnrolled = User.IsInRole("Student")
                        ? s.IsStudentEnrolled
                        : s.IsTeacherEnrolled
                })
                .ToList()
        };
    }
}
