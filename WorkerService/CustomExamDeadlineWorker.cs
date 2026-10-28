using BusinessLogic.Exams;

namespace WorkerService;

public sealed class CustomExamDeadlineWorker(
    IExamDeadlineQueue deadlines,
    ICustomExamStore store,
    IServiceScopeFactory scopes,
    TimeProvider clock,
    ILogger<CustomExamDeadlineWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessDueAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "Deadline scan failed; will retry");
            }
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }

    public async Task ProcessDueAsync(CancellationToken cancellationToken)
    {
        var due = await deadlines.GetDueAsync(clock.GetUtcNow(), 100, cancellationToken);
        foreach (var examId in due)
        {
            var exam = await store.ReadAsync(examId, cancellationToken);
            if (exam is null || exam.Status == "Submitted")
            {
                await deadlines.RemoveAsync(examId, cancellationToken);
                continue;
            }
            try
            {
                using var scope = scopes.CreateScope();
                await scope.ServiceProvider.GetRequiredService<CustomExamService>()
                    .SubmitAsync(exam.UserId, examId, cancellationToken);
                await deadlines.RemoveAsync(examId, cancellationToken);
                logger.LogInformation("Expired exam {ExamId} submitted", examId);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogWarning(ex, "Expired exam {ExamId} will be retried", examId);
                await deadlines.PostponeAsync(examId, clock.GetUtcNow().AddSeconds(30), cancellationToken);
            }
        }
    }
}
