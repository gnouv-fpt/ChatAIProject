using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Infrastructure.Interfaces;

public interface IRagasEvaluationProgressReporter
{
    Task ReportAsync(
        RagasEvaluationProgressDto progress,
        CancellationToken cancellationToken = default);
}
