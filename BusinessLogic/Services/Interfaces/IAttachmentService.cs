using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

public sealed record AttachmentResponseDto(Guid Id, Guid SessionId, string MimeType, long Size, DateTime ExpiresAt);
public interface IAttachmentService
{
    Task<AttachmentResponseDto> UploadAsync(Guid userId, Guid sessionId, string mimeType, Stream content, CancellationToken ct);
    Task<ChatImageDto> ReadAsync(Guid userId, Guid sessionId, Guid id, CancellationToken ct);
    Task DeleteAsync(Guid userId, Guid sessionId, Guid id, CancellationToken ct);
    Task CleanupAsync(CancellationToken ct);
}
