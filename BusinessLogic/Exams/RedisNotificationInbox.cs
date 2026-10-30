using System.Text.Json;
using StackExchange.Redis;

namespace BusinessLogic.Exams;

public sealed class RedisNotificationInbox(IConnectionMultiplexer redis)
{
    private static readonly TimeSpan Retention = TimeSpan.FromDays(30);

    public async Task<bool> AddAsync(ExamSubmittedEvent @event, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var db = redis.GetDatabase();
        var itemKey = ItemKey(@event.EventId);
        var inboxKey = InboxKey(@event.UserId);
        var transaction = db.CreateTransaction();
        transaction.AddCondition(Condition.KeyNotExists(itemKey));
        var saved = transaction.StringSetAsync(itemKey, JsonSerializer.Serialize(@event), Retention);
        var indexed = transaction.SortedSetAddAsync(inboxKey, @event.EventId.ToString("N"),
            @event.OccurredAtUtc.ToUnixTimeMilliseconds());
        var expiry = transaction.KeyExpireAsync(inboxKey, Retention);
        if (!await transaction.ExecuteAsync()) return false;
        await Task.WhenAll(saved, indexed, expiry);
        if (!await saved || !await expiry)
            throw new InvalidOperationException("Could not persist exam notification in Redis.");
        return true;
    }

    public async Task<IReadOnlyList<ExamSubmittedEvent>> GetRecentAsync(Guid userId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var db = redis.GetDatabase();
        var ids = await db.SortedSetRangeByRankAsync(InboxKey(userId), 0, 49, Order.Descending);
        var result = new List<ExamSubmittedEvent>(ids.Length);
        foreach (var id in ids)
        {
            var value = await db.StringGetAsync($"exam-notification:item:{id}");
            if (value.IsNullOrEmpty) continue;
            var item = JsonSerializer.Deserialize<ExamSubmittedEvent>(value!);
            if (item is not null && item.UserId == userId) result.Add(item);
        }
        return result;
    }

    private static RedisKey ItemKey(Guid eventId) => $"exam-notification:item:{eventId:N}";
    private static RedisKey InboxKey(Guid userId) => $"exam-notification:inbox:{userId:N}";
}
