using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.Document;

[Authorize]
public sealed class DownloadModel : AppPageModel
{
    private readonly IDocumentService _documentService;

    public DownloadModel(IDocumentService documentService)
    {
        _documentService = documentService;
    }

    public async Task<IActionResult> OnGetAsync(int id, CancellationToken cancellationToken)
    {
        var file = await _documentService.GetDocumentFileAsync(
            id,
            GetCurrentUserId(),
            GetCurrentUserRole(),
            cancellationToken);

        if (file is null)
        {
            TempData["ErrorMessage"] = "Không tìm thấy tài liệu hoặc bạn không có quyền tải xuống.";
            return RedirectToPage("/Document/Index");
        }

        var (filePath, originalFileName) = file.Value;
        var mimeType = GetMimeType(originalFileName);
        var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
        return File(fileStream, mimeType, originalFileName);
    }

    private static string GetMimeType(string fileName)
    {
        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        return ext switch
        {
            ".pdf" => "application/pdf",
            ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            _ => "application/octet-stream"
        };
    }
}
