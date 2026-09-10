using BusinessObject.Enums;

namespace Presentation.Models;

public sealed class DocumentChunksViewModel
{
    public int DocumentId { get; set; }
    public int SubjectId { get; set; }
    public string SubjectName { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string OriginalFileName { get; set; } = string.Empty;
    public string FileType { get; set; } = string.Empty;
    public long? FileSizeBytes { get; set; }
    public string? UploadedByName { get; set; }
    public DocumentStatus Status { get; set; }
    public DateTime UploadedAt { get; set; }
    public DateTime? IndexedAt { get; set; }
    public int TotalChunks { get; set; }
    public int TotalTokens { get; set; }
    public int CurrentPage { get; set; }
    public int PageSize { get; set; }
    public int TotalPages { get; set; }
    public IReadOnlyList<DocumentChunkItemViewModel> Chunks { get; set; } = [];
}

public sealed class DocumentChunkItemViewModel
{
    public int Id { get; set; }
    public int ChunkIndex { get; set; }
    public int? PageNumber { get; set; }
    public int? SlideNumber { get; set; }
    public int TokenCount { get; set; }
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}
