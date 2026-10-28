using BusinessLogic.Exams;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using WorkerService;

namespace BusinessLogic.Tests;

public sealed class CustomExamDeadlineWorkerTests
{
    [Fact]
    public async Task Failed_deadline_submission_is_retried_with_same_attempt_after_worker_restart()
    {
        var store = new MemoryStore();
        var queue = new MemoryQueue();
        var sink = new MemorySink { FailFirst = true };
        var clock = new ManualClock();
        using var services = new ServiceCollection()
            .AddSingleton<ICustomExamStore>(store)
            .AddSingleton<IExamQuestionSource, OneQuestionSource>()
            .AddSingleton<IExamResultSink>(sink)
            .AddSingleton<IExamEventPublisher, NoopPublisher>()
            .AddSingleton<TimeProvider>(clock)
            .AddScoped<CustomExamService>()
            .BuildServiceProvider();
        var examService = services.GetRequiredService<CustomExamService>();
        var owner = Guid.NewGuid();
        var exam = await examService.CreateAsync(owner, new("signs", "v1", 1, 1));
        queue.Due.Add(exam.ExamId);
        clock.Advance(TimeSpan.FromMinutes(2));

        var worker = NewWorker(queue, store, services, clock);
        await worker.ProcessDueAsync(default);
        Assert.Contains(exam.ExamId, queue.Due);
        Assert.Equal("Submitting", (await store.ReadAsync(exam.ExamId, default))?.Status);

        var restarted = NewWorker(queue, store, services, clock);
        await restarted.ProcessDueAsync(default);
        Assert.Empty(queue.Due);
        Assert.Single(sink.Results);
        Assert.Equal("Submitted", (await store.ReadAsync(exam.ExamId, default))?.Status);
    }

    private static CustomExamDeadlineWorker NewWorker(MemoryQueue queue, MemoryStore store,
        IServiceProvider services, TimeProvider clock) => new(queue, store,
        services.GetRequiredService<IServiceScopeFactory>(), clock,
        NullLogger<CustomExamDeadlineWorker>.Instance);

    private sealed class ManualClock : TimeProvider
    {
        private DateTimeOffset _now = DateTimeOffset.Parse("2026-10-28T00:00:00Z");
        public override DateTimeOffset GetUtcNow() => _now;
        public void Advance(TimeSpan amount) => _now += amount;
    }

    private sealed class OneQuestionSource : IExamQuestionSource
    {
        public Task<IReadOnlyList<BankQuestion>> GetQuestionsAsync(string categoryId,
            string bankVersion, int count, CancellationToken cancellationToken) =>
            Task.FromResult<IReadOnlyList<BankQuestion>>(
                [new("q1", "v1", "Question", [new("a", "A"), new("b", "B")], "a")]);
    }

    private sealed class NoopPublisher : IExamEventPublisher
    {
        public Task PublishAsync(ExamSubmittedEvent @event, CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class MemorySink : IExamResultSink
    {
        public bool FailFirst { get; set; }
        public List<SaveExamResult> Results { get; } = [];
        public Task SaveAsync(SaveExamResult result, CancellationToken cancellationToken)
        {
            if (FailFirst) { FailFirst = false; throw new InvalidOperationException("User DB unavailable"); }
            if (Results.All(x => x.AttemptId != result.AttemptId)) Results.Add(result);
            return Task.CompletedTask;
        }
    }

    private sealed class MemoryQueue : IExamDeadlineQueue
    {
        public List<Guid> Due { get; } = [];
        public Task<IReadOnlyList<Guid>> GetDueAsync(DateTimeOffset nowUtc, int limit,
            CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<Guid>>(Due.ToArray());
        public Task RemoveAsync(Guid examId, CancellationToken cancellationToken)
        {
            Due.Remove(examId);
            return Task.CompletedTask;
        }
        public Task PostponeAsync(Guid examId, DateTimeOffset nextAttemptUtc,
            CancellationToken cancellationToken) => Task.CompletedTask;
    }

    private sealed class MemoryStore : ICustomExamStore
    {
        private readonly Dictionary<Guid, StoredExam> _items = [];
        public Task<bool> CreateAsync(StoredExam exam, TimeSpan ttl, CancellationToken cancellationToken) =>
            Task.FromResult(_items.TryAdd(exam.ExamId, exam));
        public Task<StoredExam?> ReadAsync(Guid examId, CancellationToken cancellationToken) =>
            Task.FromResult(_items.GetValueOrDefault(examId));
        public Task<bool> CompareExchangeAsync(StoredExam original, StoredExam updated,
            CancellationToken cancellationToken)
        {
            if (!_items.TryGetValue(original.ExamId, out var current) || current.Revision != original.Revision)
                return Task.FromResult(false);
            _items[original.ExamId] = updated;
            return Task.FromResult(true);
        }
    }
}
