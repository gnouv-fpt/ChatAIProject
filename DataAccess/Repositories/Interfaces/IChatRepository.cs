using BusinessObject.Entities;
using DataAccess.Repositories.Models;

namespace DataAccess.Repositories.Interfaces;

public interface IChatRepository
{
    Task<ChatSession?> GetSessionByIdAsync(int sessionId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ChatSession>> GetSessionsByUserAsync(int? userId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ChatSession>> GetSessionsByUserAndSubjectAsync(
        int? userId,
        int subjectId,
        CancellationToken cancellationToken = default);

    Task<ChatSession> CreateSessionAsync(ChatSession session, CancellationToken cancellationToken = default);

    Task UpdateSessionAsync(ChatSession session, CancellationToken cancellationToken = default);

    Task<ChatMessage> AddMessageAsync(ChatMessage message, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ChatMessage>> GetMessagesBySessionIdAsync(
        int sessionId,
        CancellationToken cancellationToken = default);

    Task<int> CountSessionsAsync(CancellationToken cancellationToken = default);

    Task<int> CountMessagesAsync(CancellationToken cancellationToken = default);

    Task<TokenUsageAggregate> GetTokenUsageAsync(CancellationToken cancellationToken = default);

    Task<TokenUsageAggregate> GetTokenUsageByUserAsync(int userId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<UserTokenUsageAggregate>> GetTokenUsageByUsersAsync(CancellationToken cancellationToken = default);
}
