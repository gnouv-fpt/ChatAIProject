using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface ICrawlJobRepository
{
    Task SaveAsync(CrawlJob job, CancellationToken cancellationToken = default);
    Task<CrawlJob?> GetAsync(Guid id, CancellationToken cancellationToken = default);
}
