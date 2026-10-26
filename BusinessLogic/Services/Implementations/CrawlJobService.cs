using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

// Synchronous execution with durable status; no detached task using a disposed request scope.
public sealed class CrawlJobService(ICrawlerService crawler, ICrawlJobRepository jobs, ILogger<CrawlJobService> logger) : ICrawlJobService
{
    private static readonly string Instance = Guid.NewGuid().ToString("N");
    private static readonly SemaphoreSlim Gate = new(1, 1);
    public async Task<CrawlJob> RunAsync(CancellationToken cancellationToken = default)
    {
        if (!await Gate.WaitAsync(0, cancellationToken)) throw new ConflictException("Một lượt cào đang chạy. Vui lòng thử lại sau.");
        var job = new CrawlJob(Guid.NewGuid(), "Running", DateTime.UtcNow, null, Instance);
        try
        {
            await jobs.SaveAsync(job, cancellationToken);
            try
            {
                await crawler.CrawlTrafficLawsAsync(cancellationToken);
                job = job with { Status = "Completed", FinishedAt = DateTime.UtcNow };
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                await jobs.SaveAsync(job with { Status = "Cancelled", FinishedAt = DateTime.UtcNow }, CancellationToken.None);
                throw;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Crawl job {JobId} failed", job.Id);
                job = job with { Status = "Failed", FinishedAt = DateTime.UtcNow };
                await jobs.SaveAsync(job, CancellationToken.None);
                throw new AppException(502, $"Cào dữ liệu thất bại. Mã lượt cào: {job.Id}. Vui lòng kiểm tra nguồn hoặc thử lại.");
            }
            await jobs.SaveAsync(job, CancellationToken.None);
            return job;
        }
        finally { Gate.Release(); }
    }
    public async Task<CrawlJob> GetAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var job = await jobs.GetAsync(id, cancellationToken) ?? throw new NotFoundException("Không tìm thấy lượt cào.");
        return job.Status == "Running" && job.InstanceId != Instance ? job with { Status = "Interrupted" } : job;
    }
}
