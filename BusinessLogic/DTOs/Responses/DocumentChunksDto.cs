using BusinessObject.Enums;

namespace BusinessLogic.DTOs.Responses;

public sealed record DocumentChunksDto(
    int DocumentId,
    int SubjectId,
    string SubjectName,
    string Title,
    string OriginalFileName,
    string FileType,
    long? FileSizeBytes,
    string? UploadedByName,
    DocumentStatus Status,
    DateTime UploadedAt,
    DateTime? IndexedAt,
    int TotalChunks,
    int TotalTokens,
    int CurrentPage,
    int PageSize,
    int TotalPages,
    IReadOnlyList<DocumentChunkItemDto> Chunks);

public sealed record DocumentChunkItemDto(
    int Id,
    int ChunkIndex,
    int? PageNumber,
    int? SlideNumber,
    int TokenCount,
    string Content,
    DateTime CreatedAt);
