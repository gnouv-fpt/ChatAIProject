namespace BusinessLogic.Services.Interfaces;

public interface ICrawlerService
{
    Task CrawlTrafficLawsAsync(CancellationToken cancellationToken = default);
}