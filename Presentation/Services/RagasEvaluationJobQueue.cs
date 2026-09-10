using System.Collections.Concurrent;
using System.Threading.Channels;
using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure.Interfaces;
using Microsoft.AspNetCore.SignalR;
using Presentation.Hubs;

namespace Presentation.Services;

public sealed class RagasEvaluationJobQueue : IRagasEvaluationJobQueue
{
    private static readonly TimeSpan TerminalRetention = TimeSpan.FromMinutes(30);

    private readonly Channel<RagasEvaluationJobRequest> _channel =
        Channel.CreateUnbounded<RagasEvaluationJobRequest>(
            new UnboundedChannelOptions
            {
                SingleReader = true,
                SingleWriter = false
            });

    private readonly ConcurrentDictionary<string, JobState> _states = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<string> _pendingEvaluationIds = new();
    private readonly object _syncRoot = new();
    private readonly IHubContext<RagasEvaluationProgressHub> _hubContext;
    private readonly ILogger<RagasEvaluationJobQueue> _logger;

    public RagasEvaluationJobQueue(
        IHubContext<RagasEvaluationProgressHub> hubContext,
        ILogger<RagasEvaluationJobQueue> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    public async Task<RagasEvaluationJobStatusDto> EnqueueAsync(
        RagasEvaluationJobRequest request,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(request.EvaluationId))
        {
            throw new ArgumentException("Evaluation id is required.", nameof(request));
        }

        List<RagasEvaluationJobStatusDto> queueUpdates;
        RagasEvaluationJobStatusDto status;

        lock (_syncRoot)
        {
            CleanupExpiredTerminalStates(DateTimeOffset.UtcNow);

            if (_states.ContainsKey(request.EvaluationId))
            {
                throw new InvalidOperationException("Phiên đánh giá này đã tồn tại.");
            }

            var state = JobState.Create(request);
            _states[request.EvaluationId] = state;
            _pendingEvaluationIds.Add(request.EvaluationId);
            queueUpdates = BuildQueuedStatusesUnsafe();
            status = BuildStatusUnsafe(state);
        }

        await _channel.Writer.WriteAsync(request, cancellationToken);
        await BroadcastManyAsync(queueUpdates, cancellationToken);
        return status;
    }

    public ValueTask<RagasEvaluationJobRequest> DequeueAsync(CancellationToken cancellationToken)
    {
        return _channel.Reader.ReadAsync(cancellationToken);
    }

    public Task<RagasEvaluationJobStatusDto?> GetStatusAsync(
        int userId,
        string evaluationId,
        CancellationToken cancellationToken = default)
    {
        lock (_syncRoot)
        {
            CleanupExpiredTerminalStates(DateTimeOffset.UtcNow);
            if (!_states.TryGetValue(evaluationId, out var state)
                || state.Request.UserId != userId)
            {
                return Task.FromResult<RagasEvaluationJobStatusDto?>(null);
            }

            return Task.FromResult<RagasEvaluationJobStatusDto?>(BuildStatusUnsafe(state));
        }
    }

    public Task<IReadOnlyList<RagasEvaluationJobStatusDto>> GetUserJobsAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        lock (_syncRoot)
        {
            CleanupExpiredTerminalStates(DateTimeOffset.UtcNow);
            var jobs = _states.Values
                .Where(state => state.Request.UserId == userId)
                .Select(BuildStatusUnsafe)
                .OrderBy(status => StatusPriority(status.Status))
                .ThenBy(status => status.QueuePosition ?? int.MaxValue)
                .ThenByDescending(status => status.EnqueuedAt)
                .ToList();

            return Task.FromResult<IReadOnlyList<RagasEvaluationJobStatusDto>>(jobs);
        }
    }

    public async Task<RagasEvaluationJobStatusDto?> MarkRunningAsync(
        string evaluationId,
        CancellationToken cancellationToken = default)
    {
        List<RagasEvaluationJobStatusDto> queueUpdates;
        RagasEvaluationJobStatusDto? status = null;

        lock (_syncRoot)
        {
            CleanupExpiredTerminalStates(DateTimeOffset.UtcNow);
            if (_states.TryGetValue(evaluationId, out var state))
            {
                _pendingEvaluationIds.RemoveAll(id => string.Equals(id, evaluationId, StringComparison.OrdinalIgnoreCase));
                state.Status = RagasEvaluationJobStatuses.Running;
                state.Stage = "Running";
                state.StartedAt ??= DateTimeOffset.UtcNow;
                state.Message = "Đang chạy đánh giá RAG...";
                state.QueuePosition = null;
                status = BuildStatusUnsafe(state);
            }

            queueUpdates = BuildQueuedStatusesUnsafe();
        }

        await BroadcastManyAsync(queueUpdates, cancellationToken);
        if (status is not null)
        {
            await BroadcastAsync(status, cancellationToken);
        }

        return status;
    }

    public async Task<RagasEvaluationJobStatusDto?> UpdateProgressAsync(
        RagasEvaluationProgressDto progress,
        CancellationToken cancellationToken = default)
    {
        RagasEvaluationJobStatusDto? status = null;

        lock (_syncRoot)
        {
            CleanupExpiredTerminalStates(DateTimeOffset.UtcNow);
            if (_states.TryGetValue(progress.EvaluationId, out var state))
            {
                state.Stage = progress.Stage;
                state.Percent = progress.Percent;
                state.CompletedSteps = progress.CompletedSteps;
                state.TotalSteps = progress.TotalSteps;
                state.CurrentModel = progress.CurrentModel;
                state.CurrentStrategy = progress.CurrentStrategy;
                state.CurrentQuestion = progress.CurrentQuestion;
                state.TotalQuestions = progress.TotalQuestions;
                state.ElapsedSeconds = progress.ElapsedSeconds;
                state.EstimatedRemainingSeconds = progress.EstimatedRemainingSeconds;
                state.Message = progress.Message;
                state.IsCompleted = progress.IsCompleted;
                state.IsFailed = progress.IsFailed;

                if (progress.IsCompleted)
                {
                    state.Status = RagasEvaluationJobStatuses.Completed;
                    state.Percent = 100;
                    state.FinishedAt ??= DateTimeOffset.UtcNow;
                    state.QueuePosition = null;
                }
                else if (progress.IsFailed)
                {
                    state.Status = RagasEvaluationJobStatuses.Failed;
                    state.FinishedAt ??= DateTimeOffset.UtcNow;
                    state.QueuePosition = null;
                }
                else if (state.Status != RagasEvaluationJobStatuses.Running)
                {
                    state.Status = RagasEvaluationJobStatuses.Running;
                    state.StartedAt ??= DateTimeOffset.UtcNow;
                    state.QueuePosition = null;
                }

                status = BuildStatusUnsafe(state);
            }
        }

        if (status is not null)
        {
            await BroadcastAsync(status, cancellationToken);
        }

        return status;
    }

    public Task<RagasEvaluationJobStatusDto?> MarkFailedAsync(
        string evaluationId,
        string message,
        CancellationToken cancellationToken = default)
    {
        return MarkTerminalAsync(
            evaluationId,
            RagasEvaluationJobStatuses.Failed,
            message,
            isFailed: true,
            cancellationToken);
    }

    public Task<RagasEvaluationJobStatusDto?> MarkCancelledAsync(
        string evaluationId,
        string message,
        CancellationToken cancellationToken = default)
    {
        return MarkTerminalAsync(
            evaluationId,
            RagasEvaluationJobStatuses.Cancelled,
            message,
            isFailed: true,
            cancellationToken);
    }

    private async Task<RagasEvaluationJobStatusDto?> MarkTerminalAsync(
        string evaluationId,
        string statusName,
        string message,
        bool isFailed,
        CancellationToken cancellationToken)
    {
        RagasEvaluationJobStatusDto? status = null;

        lock (_syncRoot)
        {
            CleanupExpiredTerminalStates(DateTimeOffset.UtcNow);
            if (_states.TryGetValue(evaluationId, out var state))
            {
                _pendingEvaluationIds.RemoveAll(id => string.Equals(id, evaluationId, StringComparison.OrdinalIgnoreCase));
                state.Status = statusName;
                state.Stage = statusName;
                state.Message = message;
                state.IsFailed = isFailed;
                state.IsCompleted = false;
                state.FinishedAt ??= DateTimeOffset.UtcNow;
                state.EstimatedRemainingSeconds = null;
                state.QueuePosition = null;
                status = BuildStatusUnsafe(state);
            }
        }

        if (status is not null)
        {
            await BroadcastAsync(status, cancellationToken);
        }

        return status;
    }

    private List<RagasEvaluationJobStatusDto> BuildQueuedStatusesUnsafe()
    {
        var updates = new List<RagasEvaluationJobStatusDto>();
        for (var index = 0; index < _pendingEvaluationIds.Count; index++)
        {
            var evaluationId = _pendingEvaluationIds[index];
            if (!_states.TryGetValue(evaluationId, out var state))
            {
                continue;
            }

            state.QueuePosition = index + 1;
            state.Message = state.QueuePosition == 1
                ? "Đang chờ đến lượt chạy đánh giá."
                : $"Đang chờ trong hàng đợi, vị trí {state.QueuePosition}.";
            updates.Add(BuildStatusUnsafe(state));
        }

        return updates;
    }

    private RagasEvaluationJobStatusDto BuildStatusUnsafe(JobState state)
    {
        var queuedJobsForUser = _states.Values.Count(item =>
            item.Request.UserId == state.Request.UserId
            && item.Status == RagasEvaluationJobStatuses.Queued);

        return new RagasEvaluationJobStatusDto(
            state.Request.EvaluationId,
            state.Request.UserId,
            state.Request.SubjectId,
            state.Request.SubjectName,
            state.Status,
            state.Stage,
            state.Percent,
            state.CompletedSteps,
            state.TotalSteps,
            state.CurrentModel,
            state.CurrentStrategy,
            state.CurrentQuestion,
            state.TotalQuestions,
            state.ElapsedSeconds,
            state.EstimatedRemainingSeconds,
            state.Message,
            state.QueuePosition,
            queuedJobsForUser,
            state.Request.EnqueuedAt,
            state.StartedAt,
            state.FinishedAt,
            state.IsCompleted,
            state.IsFailed);
    }

    private async Task BroadcastManyAsync(
        IReadOnlyList<RagasEvaluationJobStatusDto> statuses,
        CancellationToken cancellationToken)
    {
        foreach (var status in statuses)
        {
            await BroadcastAsync(status, cancellationToken);
        }
    }

    private async Task BroadcastAsync(
        RagasEvaluationJobStatusDto status,
        CancellationToken cancellationToken)
    {
        try
        {
            await _hubContext.Clients
                .Group(RagasEvaluationProgressGroups.ForUserEvaluation(
                    status.UserId,
                    status.EvaluationId))
                .SendAsync("RagasEvaluationProgressUpdated", status, cancellationToken);
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning(
                exception,
                "Unable to broadcast RAGAS job status for evaluation {EvaluationId}",
                status.EvaluationId);
        }
    }

    private void CleanupExpiredTerminalStates(DateTimeOffset now)
    {
        var expiredIds = _states.Values
            .Where(state => state.FinishedAt is not null
                && now - state.FinishedAt.Value > TerminalRetention)
            .Select(state => state.Request.EvaluationId)
            .ToList();

        foreach (var evaluationId in expiredIds)
        {
            _states.TryRemove(evaluationId, out _);
            _pendingEvaluationIds.RemoveAll(id => string.Equals(id, evaluationId, StringComparison.OrdinalIgnoreCase));
        }
    }

    private static int StatusPriority(string status)
    {
        return status switch
        {
            RagasEvaluationJobStatuses.Running => 0,
            RagasEvaluationJobStatuses.Queued => 1,
            _ => 2
        };
    }

    private sealed class JobState
    {
        private JobState(RagasEvaluationJobRequest request)
        {
            Request = request;
        }

        public RagasEvaluationJobRequest Request { get; }
        public string Status { get; set; } = RagasEvaluationJobStatuses.Queued;
        public string Stage { get; set; } = "Queued";
        public int Percent { get; set; }
        public int CompletedSteps { get; set; }
        public int TotalSteps { get; set; } = 1;
        public string? CurrentModel { get; set; }
        public string? CurrentStrategy { get; set; }
        public int? CurrentQuestion { get; set; }
        public int TotalQuestions { get; set; }
        public int ElapsedSeconds { get; set; }
        public int? EstimatedRemainingSeconds { get; set; }
        public string Message { get; set; } = "Đang chờ trong hàng đợi.";
        public int? QueuePosition { get; set; }
        public DateTimeOffset? StartedAt { get; set; }
        public DateTimeOffset? FinishedAt { get; set; }
        public bool IsCompleted { get; set; }
        public bool IsFailed { get; set; }

        public static JobState Create(RagasEvaluationJobRequest request)
        {
            return new JobState(request);
        }
    }
}

public static class RagasEvaluationJobStatuses
{
    public const string Queued = "Queued";
    public const string Running = "Running";
    public const string Completed = "Completed";
    public const string Failed = "Failed";
    public const string Cancelled = "Cancelled";
}
