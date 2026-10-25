using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

// Attachment metadata for the chat image API (Vương); bytes stay in private storage.
public interface IChatAttachmentRepository : IGenericRepository<ChatAttachment>
{
    // Null when missing, deleted, expired or owned by another user.
    Task<ChatAttachment?> GetOwnedAsync(
        Guid attachmentId,
        Guid userId,
        DateTime utcNow,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ChatAttachment>> GetOwnedInSessionAsync(
        IReadOnlyCollection<Guid> attachmentIds,
        Guid userId,
        Guid sessionId,
        DateTime utcNow,
        CancellationToken cancellationToken = default);

    Task<long> GetStoredBytesAsync(Guid userId, DateTime utcNow, CancellationToken cancellationToken = default);

    // Tracked, so the caller can set DeletedAt after removing the bytes.
    Task<IReadOnlyList<ChatAttachment>> GetExpiredAsync(
        DateTime utcNow,
        int take,
        CancellationToken cancellationToken = default);
}
