using System.Text.Json;
using StackExchange.Redis;

namespace BusinessLogic.Exams;

public sealed class RedisCustomExamStore : ICustomExamStore
{
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
        return await _redis.GetDatabase().StringSetAsync(Key(exam.ExamId), JsonSerializer.Serialize(exam),
            ttl, When.NotExists);
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

    private static RedisKey Key(Guid examId) => $"custom-exam:v1:{examId:N}";
}
