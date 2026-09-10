using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using DataAccess.Repositories.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class ChatRepository : IChatRepository
{
    private const string SeedDemoSessionPrefix = "[SeedDemo]";

    private readonly ChatAIWebDbContext _context;

    public ChatRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public Task<ChatSession?> GetSessionByIdAsync(
        int sessionId,
        CancellationToken cancellationToken = default)
    {
        return _context.ChatSessions
            .Include(session => session.Subject)
            .FirstOrDefaultAsync(
                session => session.Id == sessionId
                    && (session.Title == null || !session.Title.StartsWith(SeedDemoSessionPrefix)),
                cancellationToken);
    }

    public async Task<IReadOnlyList<ChatSession>> GetSessionsByUserAsync(
        int? userId,
        CancellationToken cancellationToken = default)
    {
        return await _context.ChatSessions
            .AsNoTracking()
            .Include(session => session.Subject)
            .Include(session => session.ChatMessages)
            .Where(session => session.UserId == userId
                && (session.Title == null || !session.Title.StartsWith(SeedDemoSessionPrefix)))
            .OrderByDescending(session => session.UpdatedAt ?? session.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ChatSession>> GetSessionsByUserAndSubjectAsync(
        int? userId,
        int subjectId,
        CancellationToken cancellationToken = default)
    {
        return await _context.ChatSessions
            .AsNoTracking()
            .Include(session => session.Subject)
            .Include(session => session.ChatMessages)
            .Where(session => session.UserId == userId
                && session.SubjectId == subjectId
                && (session.Title == null || !session.Title.StartsWith(SeedDemoSessionPrefix)))
            .OrderByDescending(session => session.UpdatedAt ?? session.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<ChatSession> CreateSessionAsync(
        ChatSession session,
        CancellationToken cancellationToken = default)
    {
        _context.ChatSessions.Add(session);
        await _context.SaveChangesAsync(cancellationToken);
        return session;
    }

    public async Task UpdateSessionAsync(
        ChatSession session,
        CancellationToken cancellationToken = default)
    {
        _context.ChatSessions.Update(session);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task<ChatMessage> AddMessageAsync(
        ChatMessage message,
        CancellationToken cancellationToken = default)
    {
        _context.ChatMessages.Add(message);
        await _context.SaveChangesAsync(cancellationToken);
        return message;
    }

    public async Task<IReadOnlyList<ChatMessage>> GetMessagesBySessionIdAsync(
        int sessionId,
        CancellationToken cancellationToken = default)
    {
        return await _context.ChatMessages
            .AsNoTracking()
            .Where(message => message.ChatSessionId == sessionId)
            .OrderBy(message => message.CreatedAt)
            .ThenBy(message => message.Id)
            .ToListAsync(cancellationToken);
    }

    public Task<int> CountSessionsAsync(CancellationToken cancellationToken = default)
    {
        return _context.ChatSessions
            .AsNoTracking()
            .CountAsync(cancellationToken);
    }

    public Task<int> CountMessagesAsync(CancellationToken cancellationToken = default)
    {
        return _context.ChatMessages
            .AsNoTracking()
            .CountAsync(cancellationToken);
    }

    public async Task<TokenUsageAggregate> GetTokenUsageAsync(CancellationToken cancellationToken = default)
    {
        var usage = await TokenTrackedMessages()
            .GroupBy(_ => 1)
            .Select(group => new
            {
                PromptTokens = group.Sum(message => message.PromptTokens ?? 0),
                CompletionTokens = group.Sum(message => message.CompletionTokens ?? 0),
                AnswerCount = group.Count(),
                FirstUsedAt = group.Min(message => (DateTime?)message.CreatedAt),
                LastUsedAt = group.Max(message => (DateTime?)message.CreatedAt)
            })
            .FirstOrDefaultAsync(cancellationToken);

        return usage is null
            ? new TokenUsageAggregate(0, 0, 0, 0, null, null)
            : new TokenUsageAggregate(
                usage.PromptTokens,
                usage.CompletionTokens,
                usage.PromptTokens + usage.CompletionTokens,
                usage.AnswerCount,
                usage.FirstUsedAt,
                usage.LastUsedAt);
    }

    public async Task<TokenUsageAggregate> GetTokenUsageByUserAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        var usage = await TokenTrackedMessages()
            .Where(message => message.ChatSession.UserId == userId)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                PromptTokens = group.Sum(message => message.PromptTokens ?? 0),
                CompletionTokens = group.Sum(message => message.CompletionTokens ?? 0),
                AnswerCount = group.Count(),
                FirstUsedAt = group.Min(message => (DateTime?)message.CreatedAt),
                LastUsedAt = group.Max(message => (DateTime?)message.CreatedAt)
            })
            .FirstOrDefaultAsync(cancellationToken);

        return usage is null
            ? new TokenUsageAggregate(0, 0, 0, 0, null, null)
            : new TokenUsageAggregate(
                usage.PromptTokens,
                usage.CompletionTokens,
                usage.PromptTokens + usage.CompletionTokens,
                usage.AnswerCount,
                usage.FirstUsedAt,
                usage.LastUsedAt);
    }

    public async Task<IReadOnlyList<UserTokenUsageAggregate>> GetTokenUsageByUsersAsync(
        CancellationToken cancellationToken = default)
    {
        var users = await _context.Users
            .AsNoTracking()
            .Select(user => new
            {
                user.Id,
                user.FullName,
                user.Email,
                user.Role
            })
            .ToListAsync(cancellationToken);

        var usageByUser = await TokenTrackedMessages()
            .Where(message => message.ChatSession.UserId != null)
            .GroupBy(message => message.ChatSession.UserId!.Value)
            .Select(group => new
            {
                UserId = group.Key,
                PromptTokens = group.Sum(message => message.PromptTokens ?? 0),
                CompletionTokens = group.Sum(message => message.CompletionTokens ?? 0),
                AnswerCount = group.Count(),
                LastUsedAt = group.Max(message => (DateTime?)message.CreatedAt)
            })
            .ToDictionaryAsync(usage => usage.UserId, cancellationToken);

        return users
            .Select(user =>
            {
                usageByUser.TryGetValue(user.Id, out var usage);
                var promptTokens = usage?.PromptTokens ?? 0;
                var completionTokens = usage?.CompletionTokens ?? 0;

                return new UserTokenUsageAggregate(
                    user.Id,
                    user.FullName,
                    user.Email,
                    user.Role,
                    promptTokens,
                    completionTokens,
                    promptTokens + completionTokens,
                    usage?.AnswerCount ?? 0,
                    usage?.LastUsedAt);
            })
            .OrderByDescending(usage => usage.TotalTokens)
            .ThenBy(usage => usage.FullName)
            .ToList();
    }

    private IQueryable<ChatMessage> TokenTrackedMessages()
    {
        return _context.ChatMessages
            .AsNoTracking()
            .Where(message => message.PromptTokens != null || message.CompletionTokens != null);
    }
}
