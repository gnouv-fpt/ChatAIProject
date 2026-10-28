using System.Text.Json;
using StackExchange.Redis;

namespace BusinessLogic.Exams;

public sealed class RedisCustomExamStore : ICustomExamStore, IExamDeadlineQueue
{
    private static readonly RedisKey DeadlineKey = "custom-exam:deadlines:v1";
    private const string CompareExchangeScript = """
        local current = redis.call('GET', KEYS[1])
        if not current then return 0 end
        local stored = cjson.decode(current)
        if stored.Revision ~= tonumber(ARGV[1]) then return 0 end
        redis.call('SET', KEYS[1], ARGV[2], 'KEEPTTL')
        return 1
        """;

    private readonly IConnectionMultiplexer _redis;

    public RedisCustomExamStore(IConnectionMultiplexer redis) => _redis = redis;

    public async Task<bool> CreateAsync(StoredExam exam, TimeSpan ttl, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (ttl <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(ttl));
        var transaction = _redis.GetDatabase().CreateTransaction();
        transaction.AddCondition(Condition.KeyNotExists(Key(exam.ExamId)));
        var stored = transaction.StringSetAsync(Key(exam.ExamId), JsonSerializer.Serialize(exam), ttl);
        var scheduled = transaction.SortedSetAddAsync(DeadlineKey, exam.ExamId.ToString("N"),
            exam.DeadlineUtc.ToUnixTimeMilliseconds());
        if (!await transaction.ExecuteAsync()) return false;
        await Task.WhenAll(stored, scheduled);
        if (!await stored) throw new InvalidOperationException("Could not store custom exam in Redis.");
        return true;
    }

    public async Task<StoredExam?> ReadAsync(Guid examId, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var value = await _redis.GetDatabase().StringGetAsync(Key(examId));
        return value.IsNullOrEmpty ? null : JsonSerializer.Deserialize<StoredExam>(value!);
    }

    public async Task<bool> CompareExchangeAsync(StoredExam original, StoredExam updated,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (original.ExamId != updated.ExamId || original.UserId != updated.UserId ||
            updated.Revision != original.Revision + 1)
            throw new ArgumentException("Invalid exam transition", nameof(updated));
        var result = await _redis.GetDatabase().ScriptEvaluateAsync(CompareExchangeScript,
            [Key(original.ExamId)], [original.Revision, JsonSerializer.Serialize(updated)]);
        return (int)result == 1;
    }

    public async Task<IReadOnlyList<Guid>> GetDueAsync(DateTimeOffset nowUtc, int limit,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (limit is < 1 or > 1000) throw new ArgumentOutOfRangeException(nameof(limit));
        var values = await _redis.GetDatabase().SortedSetRangeByScoreAsync(DeadlineKey,
            double.NegativeInfinity, nowUtc.ToUnixTimeMilliseconds(), Exclude.None,
            Order.Ascending, 0, limit);
        return values.Select(v => Guid.TryParse(v.ToString(), out var id) ? id : Guid.Empty)
            .Where(id => id != Guid.Empty).ToArray();
    }

    public async Task RemoveAsync(Guid examId, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        await _redis.GetDatabase().SortedSetRemoveAsync(DeadlineKey, examId.ToString("N"));
    }

    public async Task PostponeAsync(Guid examId, DateTimeOffset nextAttemptUtc,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        await _redis.GetDatabase().SortedSetAddAsync(DeadlineKey, examId.ToString("N"),
            nextAttemptUtc.ToUnixTimeMilliseconds());
    }

    private static RedisKey Key(Guid examId) => $"custom-exam:v1:{examId:N}";
}
