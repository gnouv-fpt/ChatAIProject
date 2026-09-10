using BusinessLogic.DTOs.Requests;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Document;

[Authorize(Roles = "Teacher")]
public sealed class UploadModel : AppPageModel
{
    private readonly IDocumentService _documentService;
    private readonly UploadSettings _uploadSettings;

    public UploadModel(
        IDocumentService documentService,
        UploadSettings uploadSettings)
    {
        _documentService = documentService;
        _uploadSettings = uploadSettings;
    }

    [BindProperty]
    public DocumentUploadViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(int? subjectId, CancellationToken cancellationToken)
    {
        var subjects = await GetSubjectOptionsAsync(cancellationToken);
        if (subjects.Count == 0)
        {
            TempData["ErrorMessage"] = "Chỉ trưởng bộ môn mới có quyền tải tài liệu lên.";
            return RedirectToPage("/Document/Index");
        }

        var selectedSubjectId = subjectId.HasValue && subjects.Any(subject => subject.Id == subjectId.Value)
            ? subjectId
            : null;

        ViewModel = new DocumentUploadViewModel
        {
            SubjectId = selectedSubjectId,
            UploadId = Guid.NewGuid().ToString("N"),
            MaxFileSizeMb = _uploadSettings.MaxFileSizeMb,
            MaxFilesPerBatch = _uploadSettings.MaxFilesPerBatch,
            MaxBatchSizeMb = _uploadSettings.MaxBatchSizeMb,
            Subjects = subjects
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (ViewModel.Files.Count == 0)
        {
            ModelState.AddModelError(nameof(ViewModel.Files), "Vui lòng chọn tài liệu để tải lên.");
        }

        if (!ModelState.IsValid)
        {
            return BadRequest(new
            {
                succeeded = false,
                message = GetFirstModelError()
            });
        }

        var fileRequests = new List<DocumentBatchUploadFileRequest>();
        var streams = new List<Stream>();

        try
        {
            foreach (var file in ViewModel.Files)
            {
                var stream = file.OpenReadStream();
                streams.Add(stream);
                fileRequests.Add(new DocumentBatchUploadFileRequest(
                    stream,
                    file.FileName,
                    file.ContentType,
                    file.Length));
            }

            var result = await _documentService.UploadBatchAndIndexAsync(
                new DocumentBatchUploadRequest(
                    string.IsNullOrWhiteSpace(ViewModel.UploadId) ? Guid.NewGuid().ToString("N") : ViewModel.UploadId,
                    fileRequests,
                    ViewModel.SubjectId.GetValueOrDefault(),
                    GetCurrentUserId(),
                    GetCurrentUserRole(),
                    ViewModel.Title),
                cancellationToken);

            return new JsonResult(new
            {
                succeeded = result.Succeeded,
                message = result.Message,
                items = result.Items.Select(item => new
                {
                    succeeded = item.Succeeded,
                    documentId = item.DocumentId,
                    fileName = item.FileName,
                    message = item.Message
                })
            });
        }
        finally
        {
            foreach (var stream in streams)
            {
                await stream.DisposeAsync();
            }
        }
    }

    private string GetFirstModelError()
    {
        return ModelState.Values
            .SelectMany(entry => entry.Errors)
            .Select(error => error.ErrorMessage)
            .FirstOrDefault(message => !string.IsNullOrWhiteSpace(message))
            ?? "Dữ liệu tải lên không hợp lệ.";
    }

    private async Task<IReadOnlyList<SubjectOptionViewModel>> GetSubjectOptionsAsync(
        CancellationToken cancellationToken)
    {
        var subjects = await _documentService.GetUploadSubjectOptionsAsync(
            GetCurrentUserId(),
            GetCurrentUserRole(),
            cancellationToken);
        return subjects
            .Select(subject => new SubjectOptionViewModel
            {
                Id = subject.Id,
                SubjectCode = subject.SubjectCode,
                SubjectName = subject.SubjectName
            })
            .ToList();
    }
}
