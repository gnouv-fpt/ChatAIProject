using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure.Interfaces;

namespace BusinessLogic.Infrastructure.Implementations;

public sealed class NoopRagasEvaluationProgressReporter : IRagasEvaluationProgressReporter
{
    public Task ReportAsync(
        RagasEvaluationProgressDto progress,
        CancellationToken cancellationToken = default)
    {
        return Task.CompletedTask;
    }
}
