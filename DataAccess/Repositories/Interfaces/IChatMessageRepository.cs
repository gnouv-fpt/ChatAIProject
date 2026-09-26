using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IChatMessageRepository : IGenericRepository<ChatMessage>
{
    Task<IReadOnlyList<ChatMessage>> GetMessagesBySessionIdAsync(Guid sessionId, CancellationToken cancellationToken = default);

    Task<ChatMessage?> GetMessageWithCitationsAsync(Guid messageId, CancellationToken cancellationToken = default);
}
