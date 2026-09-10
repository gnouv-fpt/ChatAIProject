using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure.Interfaces;

namespace Presentation.Services;

public sealed class SignalRRagasEvaluationProgressReporter : IRagasEvaluationProgressReporter
{
    private readonly IRagasEvaluationJobQueue _jobQueue;

    public SignalRRagasEvaluationProgressReporter(
        IRagasEvaluationJobQueue jobQueue)
    {
        _jobQueue = jobQueue;
    }

    public Task ReportAsync(
        RagasEvaluationProgressDto progress,
        CancellationToken cancellationToken = default)
    {
        return _jobQueue.UpdateProgressAsync(progress, cancellationToken);
    }
}
