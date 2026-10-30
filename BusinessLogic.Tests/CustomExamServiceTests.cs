using BusinessLogic.Exams;
using BusinessLogic.Exceptions;
using System.Text.Json;

namespace BusinessLogic.Tests;

public sealed class CustomExamServiceTests
{
    private static readonly Guid Owner = Guid.NewGuid();

    [Fact]
    public async Task Create_save_and_submit_keep_key_server_only_and_stable_on_retry()
    {
        var store = new MemoryStore();
        var sink = new MemorySink();
        var service = new CustomExamService(new FixedSource(), store, sink, new MemoryPublisher());
        var view = await service.CreateAsync(Owner, new("signs", "v1", 2, 30));

        Assert.DoesNotContain("correctOptionId", JsonSerializer.Serialize(view), StringComparison.OrdinalIgnoreCase);
        Assert.Equal(2, view.Questions.Select(q => q.Id).Distinct().Count());
        var first = view.Questions[0];
        var saved = await service.SaveAnswerAsync(Owner, view.ExamId, first.Id, "a", view.Revision);
        Assert.Equal("a", saved.Answers[first.Id]);
        var score = await service.SubmitAsync(Owner, view.ExamId);
        var retry = await service.SubmitAsync(Owner, view.ExamId);

        Assert.Equal(score.AttemptId, retry.AttemptId);
        Assert.Equal(score.SubmittedAtUtc, retry.SubmittedAtUtc);
        Assert.Single(sink.Results);
        Assert.Equal("Submitted", (await service.GetAsync(Owner, view.ExamId)).Status);
    }

    [Fact]
    public async Task Rejects_other_owner_stale_revision_and_changes_after_submit()
    {
        var service = new CustomExamService(new FixedSource(), new MemoryStore(), new MemorySink(), new MemoryPublisher());
        var view = await service.CreateAsync(Owner, new("signs", "v1", 2, 30));
        await Assert.ThrowsAsync<ForbiddenException>(() => service.GetAsync(Guid.NewGuid(), view.ExamId));
        await Assert.ThrowsAsync<ConflictException>(() => service.SaveAnswerAsync(Owner, view.ExamId,
            view.Questions[0].Id, "a", view.Revision + 1));
        await service.SubmitAsync(Owner, view.ExamId);
        await Assert.ThrowsAsync<ConflictException>(() => service.SaveAnswerAsync(Owner, view.ExamId,
            view.Questions[0].Id, "a", view.Revision));
    }

    [Fact]
    public async Task Save_failure_keeps_frozen_attempt_retryable()
    {
        var sink = new MemorySink { FailFirst = true };
        var service = new CustomExamService(new FixedSource(), new MemoryStore(), sink, new MemoryPublisher());
        var view = await service.CreateAsync(Owner, new("signs", "v1", 2, 30));
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.SubmitAsync(Owner, view.ExamId));
        Assert.Equal("Submitting", (await service.GetAsync(Owner, view.ExamId)).Status);
        var retry = await service.SubmitAsync(Owner, view.ExamId);
        Assert.Single(sink.Results);
        Assert.Equal(retry.AttemptId, sink.Results[0].AttemptId);
    }

    [Fact]
    public async Task Concurrent_autosaves_cannot_overwrite_each_other()
    {
        var service = new CustomExamService(new FixedSource(), new MemoryStore(), new MemorySink(), new MemoryPublisher());
        var view = await service.CreateAsync(Owner, new("signs", "v1", 2, 30));
        var attempts = await Task.WhenAll(view.Questions.Select(async q =>
        {
            try
            {
                await service.SaveAnswerAsync(Owner, view.ExamId, q.Id, "a", view.Revision);
                return true;
            }
            catch (ConflictException) { return false; }
        }));
        Assert.Single(attempts.Where(x => x));
        Assert.Single((await service.GetAsync(Owner, view.ExamId)).Answers);
    }

    [Fact]
    public async Task Deadline_blocks_autosave_but_allows_scored_submission()
    {
        var clock = new ManualClock();
        var service = new CustomExamService(new FixedSource(), new MemoryStore(),
            new MemorySink(), new MemoryPublisher(), clock);
        var view = await service.CreateAsync(Owner, new("signs", "v1", 2, 1));
        clock.Advance(TimeSpan.FromMinutes(2));
        await Assert.ThrowsAsync<ConflictException>(() => service.SaveAnswerAsync(Owner, view.ExamId,
            view.Questions[0].Id, "a", view.Revision));
        var score = await service.SubmitAsync(Owner, view.ExamId);
        Assert.Equal(0, score.Correct);
    }

    [Fact]
    public async Task Kafka_failure_keeps_saved_attempt_retryable_with_same_event_id()
    {
        var sink = new MemorySink();
        var publisher = new MemoryPublisher { FailFirst = true };
        var service = new CustomExamService(new FixedSource(), new MemoryStore(), sink, publisher);
        var view = await service.CreateAsync(Owner, new("signs", "v1", 2, 30));
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.SubmitAsync(Owner, view.ExamId));
        Assert.Equal("Submitting", (await service.GetAsync(Owner, view.ExamId)).Status);
        var score = await service.SubmitAsync(Owner, view.ExamId);
        await service.SubmitAsync(Owner, view.ExamId);
        Assert.Single(sink.Results);
        Assert.Single(publisher.Events);
        Assert.Equal(score.AttemptId, publisher.Events[0].EventId);
    }

    private sealed class FixedSource : IExamQuestionSource
    {
        public Task<IReadOnlyList<BankQuestion>> GetQuestionsAsync(string categoryId, string bankVersion,
            int count, CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<BankQuestion>>(
            [new("q1", "v1", "Question 1", [new("a", "A"), new("b", "B")], "a"),
             new("q2", "v1", "Question 2", [new("a", "A"), new("b", "B")], "b")]);
    }

    private sealed class MemorySink : IExamResultSink
    {
        public List<SaveExamResult> Results { get; } = [];
        public bool FailFirst { get; set; }
        public Task SaveAsync(SaveExamResult result, CancellationToken cancellationToken)
        {
            if (FailFirst) { FailFirst = false; throw new InvalidOperationException("User service unavailable"); }
            if (Results.All(r => r.AttemptId != result.AttemptId)) Results.Add(result);
            return Task.CompletedTask;
        }
    }

    private sealed class MemoryPublisher : IExamEventPublisher
    {
        public bool FailFirst { get; set; }
        public List<ExamSubmittedEvent> Events { get; } = [];
        public Task PublishAsync(ExamSubmittedEvent @event, CancellationToken cancellationToken)
        {
            if (FailFirst) { FailFirst = false; throw new InvalidOperationException("Kafka unavailable"); }
            Events.Add(@event);
            return Task.CompletedTask;
        }
    }

    private sealed class ManualClock : TimeProvider
    {
        private DateTimeOffset _now = DateTimeOffset.Parse("2026-10-28T00:00:00Z");
        public override DateTimeOffset GetUtcNow() => _now;
        public void Advance(TimeSpan delta) => _now += delta;
    }

    private sealed class MemoryStore : ICustomExamStore
    {
        private readonly Dictionary<Guid, StoredExam> _items = [];
        public Task<bool> CreateAsync(StoredExam exam, TimeSpan ttl, CancellationToken cancellationToken)
        {
            lock (_items) return Task.FromResult(_items.TryAdd(exam.ExamId, exam));
        }
        public Task<StoredExam?> ReadAsync(Guid examId, CancellationToken cancellationToken)
        {
            lock (_items) return Task.FromResult(_items.GetValueOrDefault(examId));
        }
        public Task<bool> CompareExchangeAsync(StoredExam original, StoredExam updated,
            CancellationToken cancellationToken)
        {
            lock (_items)
            {
                if (!_items.TryGetValue(original.ExamId, out var current) || current.Revision != original.Revision)
                    return Task.FromResult(false);
                _items[original.ExamId] = updated;
                return Task.FromResult(true);
            }
        }
    }
}
