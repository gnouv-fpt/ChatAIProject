using BusinessObject.Entities;

namespace BusinessLogic.Services.Interfaces;

public interface ICrawlJobService
{
    Task<CrawlJob> RunAsync(CancellationToken cancellationToken = default);
    Task<CrawlJob> GetAsync(Guid id, CancellationToken cancellationToken = default);
}
