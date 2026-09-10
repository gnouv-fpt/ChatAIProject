using BusinessLogic.DTOs.Requests;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;

namespace Presentation.Services;

public sealed class RagasEvaluationBackgroundService : BackgroundService
{
    private readonly IRagasEvaluationJobQueue _jobQueue;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<RagasEvaluationBackgroundService> _logger;

    public RagasEvaluationBackgroundService(
        IRagasEvaluationJobQueue jobQueue,
        IServiceScopeFactory scopeFactory,
        ILogger<RagasEvaluationBackgroundService> logger)
    {
        _jobQueue = jobQueue;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            RagasEvaluationJobRequest? job = null;

            try
            {
                job = await _jobQueue.DequeueAsync(stoppingToken);
                await _jobQueue.MarkRunningAsync(job.EvaluationId, CancellationToken.None);

                using var scope = _scopeFactory.CreateScope();
                var evaluationService = scope.ServiceProvider.GetRequiredService<IRagasEvaluationService>();

                var result = await evaluationService.RunEvaluationAsync(
                    job.SubjectId,
                    job.EmbeddingModels,
                    job.ChunkingStrategies,
                    new RagasEvaluationProgressContext(job.EvaluationId, job.UserId),
                    stoppingToken);

                if (result is null)
                {
                    await _jobQueue.MarkFailedAsync(
                        job.EvaluationId,
                        "Không thể chạy đánh giá. Vui lòng kiểm tra câu hỏi benchmark.",
                        CancellationToken.None);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                if (job is not null)
                {
                    await _jobQueue.MarkCancelledAsync(
                        job.EvaluationId,
                        "Đánh giá đã bị hủy vì ứng dụng đang dừng.",
                        CancellationToken.None);
                }
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "RAGAS evaluation background job failed for evaluation {EvaluationId}",
                    job?.EvaluationId);

                if (job is not null)
                {
                    await _jobQueue.MarkFailedAsync(
                        job.EvaluationId,
                        "Không thể chạy đánh giá. Vui lòng kiểm tra cấu hình Gemini, embedding và log hệ thống.",
                        CancellationToken.None);
                }
            }
        }
    }
}
