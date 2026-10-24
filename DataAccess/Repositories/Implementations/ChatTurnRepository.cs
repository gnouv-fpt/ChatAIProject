using System.Data;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class ChatTurnRepository(ChatAIWebDbContext db) : IChatTurnRepository
{
    public void AddCitations(IEnumerable<Citation> citations) => db.Citations.AddRange(citations);
    public Task<Dictionary<Guid, int>> CountMessagesAsync(Guid[] sessionIds, CancellationToken ct) =>
        db.ChatMessages.Where(m => sessionIds.Contains(m.SessionId) && (m.TurnState == null || m.TurnState == "Completed"))
            .GroupBy(m => m.SessionId).Select(g => new { Id = g.Key, Count = g.Count() }).ToDictionaryAsync(g => g.Id, g => g.Count, ct);
    public async Task<(long Unpublished, long Unsettled)> GetOperationalCountsAsync(CancellationToken ct) =>
        (await db.ChatMessages.LongCountAsync(m => m.EventPayload != null && m.EventPublishedAt == null, ct),
         await db.ChatMessages.LongCountAsync(m => m.TurnState == "Completed" && m.QuotaSettledAt == null, ct));
    public async Task<T> WithUserLockAsync<T>(Guid userId, Func<Task<T>> action, CancellationToken ct)
    {
        return await db.Database.CreateExecutionStrategy().ExecuteAsync(async () =>
        {
            // A retry must reload entities rather than reuse changes from a rolled-back transaction.
            db.ChangeTracker.Clear();
            await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            if (db.Database.IsSqlServer())
                await db.Users.FromSqlInterpolated($"SELECT * FROM Users WITH (UPDLOCK,HOLDLOCK) WHERE Id = {userId}").LoadAsync(ct);
            var result = await action();
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return result;
        });
    }

    public Task<ChatMessage?> GetTurnAsync(Guid sessionId, Guid requestId, CancellationToken ct) =>
        db.ChatMessages.Include(m => m.Citations).FirstOrDefaultAsync(m => m.SessionId == sessionId && m.RequestId == requestId, ct);

    public Task<List<ChatMessage>> GetReservationsAsync(Guid userId, CancellationToken ct) =>
        db.ChatMessages.Where(m => m.Session.UserId == userId && m.QuotaSettledAt == null && m.ReservedTokens > 0).ToListAsync(ct);

    public Task<List<DocumentChunk>> GetChunksAsync(Guid[] ids, CancellationToken ct) =>
        db.DocumentChunks.Include(c => c.Document).Where(c => ids.Contains(c.Id)).ToListAsync(ct);

    public Task<List<ChatMessage>> GetContextAsync(Guid sessionId, CancellationToken ct) =>
        db.ChatMessages.AsNoTracking().Where(m => m.SessionId == sessionId && (m.TurnState == null || m.TurnState == "Completed"))
            .OrderByDescending(m => m.CreatedAt).Take(12).ToListAsync(ct);
}
