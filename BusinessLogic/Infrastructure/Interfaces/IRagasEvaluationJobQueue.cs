using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Infrastructure.Interfaces;

public interface IRagasEvaluationJobQueue
{
    Task<RagasEvaluationJobStatusDto> EnqueueAsync(
        RagasEvaluationJobRequest request,
        CancellationToken cancellationToken = default);

    ValueTask<RagasEvaluationJobRequest> DequeueAsync(CancellationToken cancellationToken);

    Task<RagasEvaluationJobStatusDto?> GetStatusAsync(
        int userId,
        string evaluationId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RagasEvaluationJobStatusDto>> GetUserJobsAsync(
        int userId,
        CancellationToken cancellationToken = default);

    Task<RagasEvaluationJobStatusDto?> MarkRunningAsync(
        string evaluationId,
        CancellationToken cancellationToken = default);

    Task<RagasEvaluationJobStatusDto?> UpdateProgressAsync(
        RagasEvaluationProgressDto progress,
        CancellationToken cancellationToken = default);

    Task<RagasEvaluationJobStatusDto?> MarkFailedAsync(
        string evaluationId,
        string message,
        CancellationToken cancellationToken = default);

    Task<RagasEvaluationJobStatusDto?> MarkCancelledAsync(
        string evaluationId,
        string message,
        CancellationToken cancellationToken = default);
}
