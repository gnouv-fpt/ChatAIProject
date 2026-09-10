using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Document;

[Authorize]
public sealed class IndexModel : AppPageModel
{
    private readonly IDocumentService _documentService;

    public IndexModel(IDocumentService documentService)
    {
        _documentService = documentService;
    }

    public DocumentIndexViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(
        string? searchTerm,
        int? subjectId,
        DocumentStatus? status,
        CancellationToken cancellationToken)
    {
        var result = await _documentService.GetDocumentsAsync(
            new DocumentListRequestDto(
                searchTerm,
                subjectId,
                status,
                GetCurrentUserId(),
                GetCurrentUserRole()),
            cancellationToken);
        var uploadSubjects = await _documentService.GetUploadSubjectOptionsAsync(
            GetCurrentUserId(),
            GetCurrentUserRole(),
            cancellationToken);

        ViewModel = new DocumentIndexViewModel
        {
            SearchTerm = searchTerm,
            SubjectId = subjectId,
            Status = status,
            CanUploadCurrentSubject = subjectId.HasValue
                && uploadSubjects.Any(subject => subject.Id == subjectId.Value),
            CanDeleteCurrentSubject = subjectId.HasValue
                && uploadSubjects.Any(subject => subject.Id == subjectId.Value),
            Subjects = MapSubjects(result.Subjects),
            Documents = result.Documents.Select(MapDocumentListItem).ToList()
        };
    }

    public async Task<IActionResult> OnPostDeleteAsync(
        int documentId,
        int subjectId,
        CancellationToken cancellationToken)
    {
        var result = await _documentService.DeleteAsync(
            documentId,
            GetCurrentUserId(),
            GetCurrentUserRole(),
            cancellationToken);

        TempData[result.Succeeded ? "SuccessMessage" : "ErrorMessage"] = result.Message;
        return RedirectToPage("/Document/Index", new { subjectId });
    }
    private static IReadOnlyList<SubjectOptionViewModel> MapSubjects(
        IReadOnlyList<SubjectOptionDto> subjects)
    {
        return subjects
            .Select(subject => new SubjectOptionViewModel
            {
                Id = subject.Id,
                SubjectCode = subject.SubjectCode,
                SubjectName = subject.SubjectName
            })
            .ToList();
    }

    private static DocumentListItemViewModel MapDocumentListItem(DocumentListItemDto document)
    {
        return new DocumentListItemViewModel
        {
            Id = document.Id,
            SubjectId = document.SubjectId,
            SubjectName = document.SubjectName,
            Title = document.Title,
            OriginalFileName = document.OriginalFileName,
            FileType = document.FileType,
            FileSizeBytes = document.FileSizeBytes,
            UploadedByName = document.UploadedByName,
            Status = document.Status,
            ErrorMessage = document.ErrorMessage,
            UploadedAt = document.UploadedAt,
            IndexedAt = document.IndexedAt,
            ChunkCount = document.ChunkCount,
            TotalTokenCount = document.TotalTokenCount,
            EmbeddingModel = document.EmbeddingModel,
            PreviewChunkIndex = document.PreviewChunkIndex,
            PreviewContent = document.PreviewContent
        };
    }
}
