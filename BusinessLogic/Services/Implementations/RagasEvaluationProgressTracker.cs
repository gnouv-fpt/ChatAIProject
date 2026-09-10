using System.Diagnostics;
using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

internal sealed class RagasEvaluationProgressTracker
{
    private readonly RagasEvaluationProgressContext _context;
    private readonly int _subjectId;
    private readonly int _totalSteps;
    private readonly int _totalQuestions;
    private readonly IRagasEvaluationProgressReporter _reporter;
    private readonly ILogger _logger;
    private readonly Stopwatch _stopwatch = Stopwatch.StartNew();
    private int _completedSteps;
    private bool _canEstimate;

    public RagasEvaluationProgressTracker(
        RagasEvaluationProgressContext context,
        int subjectId,
        int totalSteps,
        int totalQuestions,
        IRagasEvaluationProgressReporter reporter,
        ILogger logger)
    {
        _context = context;
        _subjectId = subjectId;
        _totalSteps = Math.Max(1, totalSteps);
        _totalQuestions = Math.Max(0, totalQuestions);
        _reporter = reporter;
        _logger = logger;
    }

    public async Task ReportAsync(
        string stage,
        string message,
        int advanceSteps = 0,
        string? currentModel = null,
        string? currentStrategy = null,
        int? currentQuestion = null,
        bool enableEstimate = false,
        bool isCompleted = false,
        bool isFailed = false,
        CancellationToken cancellationToken = default)
    {
        _completedSteps = Math.Clamp(_completedSteps + Math.Max(0, advanceSteps), 0, _totalSteps);
        _canEstimate |= enableEstimate;

        var elapsedSeconds = Math.Max(0, (int)Math.Floor(_stopwatch.Elapsed.TotalSeconds));
        var percent = isCompleted
            ? 100
            : Math.Min(99, (int)Math.Floor(_completedSteps * 100d / _totalSteps));
        var estimatedRemainingSeconds = CalculateEstimatedRemainingSeconds();

        var progress = new RagasEvaluationProgressDto(
            _context.EvaluationId,
            _context.UserId,
            _subjectId,
            stage,
            percent,
            _completedSteps,
            _totalSteps,
            currentModel,
            currentStrategy,
            currentQuestion,
            _totalQuestions,
            elapsedSeconds,
            isCompleted || isFailed ? null : estimatedRemainingSeconds,
            message,
            isCompleted,
            isFailed);

        try
        {
            await _reporter.ReportAsync(progress, cancellationToken);
        }
        catch (Exception exception) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning(
                exception,
                "Unable to publish RAGAS progress for evaluation {EvaluationId}",
                _context.EvaluationId);
        }
    }

    private int? CalculateEstimatedRemainingSeconds()
    {
        if (!_canEstimate || _completedSteps <= 0 || _completedSteps >= _totalSteps)
        {
            return null;
        }

        var secondsPerStep = _stopwatch.Elapsed.TotalSeconds / _completedSteps;
        return Math.Max(
            1,
            (int)Math.Ceiling(secondsPerStep * (_totalSteps - _completedSteps)));
    }
}
