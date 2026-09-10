using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Dashboard;

[Authorize]
public sealed class IndexModel : AppPageModel
{
    private readonly ISubjectService _subjectService;

    public IndexModel(ISubjectService subjectService)
    {
        _subjectService = subjectService;
    }

    public DashboardViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        if (User.IsInRole("Admin"))
        {
            return RedirectToPage("/AdminDashboard/Index");
        }

        var dashboard = await _subjectService.GetStudentDashboardAsync(GetCurrentUserId(), cancellationToken);

        ViewModel = new DashboardViewModel
        {
            UserName = User.Identity?.Name ?? "Sinh viên",
            SubjectCount = dashboard.SubjectCount,
            ChatSessionCount = dashboard.ChatSessionCount,
            IndexedDocumentCount = dashboard.IndexedDocumentCount,
            RecentCourses = dashboard.RecentCourses
                .Select(c => new RecentCourseViewModel
                {
                    Id = c.Id,
                    SubjectCode = c.SubjectCode,
                    SubjectName = c.SubjectName,
                    Description = c.Description,
                    DocumentCount = c.DocumentCount,
                    IndexedDocumentCount = c.IndexedDocumentCount,
                    ChatSessionCount = c.ChatSessionCount,
                    ProgressPercent = c.ProgressPercent
                })
                .ToList()
        };

        return Page();
    }
}
