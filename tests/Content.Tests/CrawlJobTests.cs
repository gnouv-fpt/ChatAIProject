using BusinessLogic.Exceptions;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using DataAccess.Repositories.Implementations;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Content.Tests;

public sealed class CrawlJobTests : IDisposable
{
    private readonly string _path = Path.Combine(Path.GetTempPath(), "crawl-tests-" + Guid.NewGuid().ToString("N"));
    [Fact]
    public async Task FailuresAreDurableAndNeverReportedCompleted()
    {
        var repo = new FileCrawlJobRepository(_path);
        var service = new CrawlJobService(new FailingCrawler(), repo, NullLogger<CrawlJobService>.Instance);
        await Assert.ThrowsAsync<AppException>(() => service.RunAsync());
        var job = System.Text.Json.JsonSerializer.Deserialize<CrawlJob>(await File.ReadAllTextAsync(Directory.GetFiles(_path, "*.json").Single()))!;
        Assert.Equal("Failed", job.Status);
        Assert.NotNull(job.FinishedAt);
        Assert.Equal(job, await new FileCrawlJobRepository(_path).GetAsync(job.Id));
        Assert.Equal("Failed", (await service.GetAsync(job.Id)).Status);
    }
    [Fact]
    public async Task PreviousProcessRunningJobIsShownInterrupted()
    {
        var repo = new FileCrawlJobRepository(_path);
        var job = new CrawlJob(Guid.NewGuid(), "Running", DateTime.UtcNow, null, "old-process");
        await repo.SaveAsync(job);
        var service = new CrawlJobService(new FailingCrawler(), repo, NullLogger<CrawlJobService>.Instance);
        Assert.Equal("Interrupted", (await service.GetAsync(job.Id)).Status);
        await Assert.ThrowsAsync<NotFoundException>(() => service.GetAsync(Guid.NewGuid()));
    }
    private sealed class FailingCrawler : ICrawlerService
    {
        public Task CrawlTrafficLawsAsync(CancellationToken cancellationToken = default) => throw new HttpRequestException("test provider outage");
    }
    public void Dispose() { if (Directory.Exists(_path)) Directory.Delete(_path, true); }
}
