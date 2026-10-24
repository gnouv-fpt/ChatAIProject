using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IChatTurnRepository
{
    Task<T> WithUserLockAsync<T>(Guid userId, Func<Task<T>> action, CancellationToken cancellationToken);
    Task<ChatMessage?> GetTurnAsync(Guid sessionId, Guid requestId, CancellationToken cancellationToken);
    Task<List<ChatMessage>> GetReservationsAsync(Guid userId, CancellationToken cancellationToken);
    Task<List<DocumentChunk>> GetChunksAsync(Guid[] ids, CancellationToken cancellationToken);
    Task<List<ChatMessage>> GetContextAsync(Guid sessionId, CancellationToken cancellationToken);
    void AddCitations(IEnumerable<Citation> citations);
    Task<Dictionary<Guid, int>> CountMessagesAsync(Guid[] sessionIds, CancellationToken cancellationToken);
    Task<(long Unpublished, long Unsettled)> GetOperationalCountsAsync(CancellationToken cancellationToken);
}
