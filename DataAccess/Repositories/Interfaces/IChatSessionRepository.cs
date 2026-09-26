using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IChatSessionRepository : IGenericRepository<ChatSession>
{
    Task<ChatSession?> GetSessionWithMessagesAsync(Guid sessionId, Guid userId, CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<ChatSession> Items, int TotalCount)> GetUserSessionsPagedAsync(
        Guid userId,
        int pageIndex,
        int pageSize,
        string? search = null,
        CancellationToken cancellationToken = default);

    Task<bool> SoftDeleteSessionAsync(Guid sessionId, Guid userId, CancellationToken cancellationToken = default);
}
