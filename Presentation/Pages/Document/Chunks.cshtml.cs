using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Document;

[Authorize]
public sealed class ChunksModel : AppPageModel
{
    private readonly IDocumentService _documentService;

    public ChunksModel(IDocumentService documentService)
    {
        _documentService = documentService;
    }

    public DocumentChunksViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(
        int id,
        [FromQuery(Name = "currentPage")] int? currentPage = null,
        [FromQuery(Name = "page")] int? legacyPage = null,
        int pageSize = 5,
        CancellationToken cancellationToken = default)
    {
        var requestedPage = currentPage ?? legacyPage ?? 1;
        var result = await _documentService.GetDocumentChunksAsync(
            id,
            requestedPage,
            pageSize,
            GetCurrentUserId(),
            GetCurrentUserRole(),
            cancellationToken);

        if (result is null)
        {
            TempData["ErrorMessage"] = "Không tìm thấy tài liệu hoặc bạn không có quyền xem phân đoạn.";
            return RedirectToPage("/Document/Index");
        }

        ViewModel = MapDocumentChunks(result);
        return Page();
    }

    private static DocumentChunksViewModel MapDocumentChunks(DocumentChunksDto document)
    {
        return new DocumentChunksViewModel
        {
            DocumentId = document.DocumentId,
            SubjectId = document.SubjectId,
            SubjectName = document.SubjectName,
            Title = document.Title,
            OriginalFileName = document.OriginalFileName,
            FileType = document.FileType,
            FileSizeBytes = document.FileSizeBytes,
            UploadedByName = document.UploadedByName,
            Status = document.Status,
            UploadedAt = document.UploadedAt,
            IndexedAt = document.IndexedAt,
            TotalChunks = document.TotalChunks,
            TotalTokens = document.TotalTokens,
            CurrentPage = document.CurrentPage,
            PageSize = document.PageSize,
            TotalPages = document.TotalPages,
            Chunks = document.Chunks.Select(chunk => new DocumentChunkItemViewModel
            {
                Id = chunk.Id,
                ChunkIndex = chunk.ChunkIndex,
                PageNumber = chunk.PageNumber,
                SlideNumber = chunk.SlideNumber,
                TokenCount = chunk.TokenCount,
                Content = chunk.Content,
                CreatedAt = chunk.CreatedAt
            }).ToList()
        };
    }
}
