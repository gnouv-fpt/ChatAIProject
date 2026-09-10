using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Presentation.Models;

namespace Presentation.Pages.AdminDashboard;

[Authorize(Roles = "Admin")]
public sealed class IndexModel : AppPageModel
{
    private readonly IAdminDashboardService _dashboardService;

    public IndexModel(IAdminDashboardService dashboardService)
    {
        _dashboardService = dashboardService;
    }

    public AdminDashboardViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var data = await _dashboardService.GetDashboardAsync(cancellationToken);
        ViewModel = new AdminDashboardViewModel
        {
            StudentCount = data.StudentCount,
            TeacherCount = data.TeacherCount,
            AdminCount = data.AdminCount,
            SubjectCount = data.SubjectCount,
            TotalDocumentCount = data.TotalDocumentCount,
            IndexedDocumentCount = data.IndexedDocumentCount,
            ProcessingDocumentCount = data.ProcessingDocumentCount,
            FailedDocumentCount = data.FailedDocumentCount,
            PdfCount = data.PdfCount,
            DocxCount = data.DocxCount,
            PptxCount = data.PptxCount,
            EvaluationQuestionCount = data.EvaluationQuestionCount,
            BenchmarkRunCount = data.BenchmarkRunCount,
            ChatSessionCount = data.ChatSessionCount,
            ChatMessageCount = data.ChatMessageCount,
            RecentDocuments = data.RecentDocuments.Select(d => new RecentDocumentItem
            {
                Id = d.Id,
                Title = d.Title,
                FileType = d.FileType,
                SubjectName = d.SubjectName,
                Status = d.Status,
                UploadedAt = d.UploadedAt
            }).ToList(),
            RecentBenchmarks = data.RecentBenchmarks.Select(b => new RecentBenchmarkItem
            {
                Id = b.Id,
                SubjectName = b.SubjectName,
                EmbeddingModel = b.EmbeddingModel,
                LlmModel = b.LlmModel,
                RecallAt5 = b.RecallAt5,
                CreatedAt = b.CreatedAt
            }).ToList()
        };
    }
}
