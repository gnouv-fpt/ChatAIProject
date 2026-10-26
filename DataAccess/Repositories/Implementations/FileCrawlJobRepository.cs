using System.Text.Json;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;

namespace DataAccess.Repositories.Implementations;

public sealed class FileCrawlJobRepository(string root) : ICrawlJobRepository
{
    private readonly string _root = Path.GetFullPath(root);
    public async Task SaveAsync(CrawlJob job, CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(_root);
        var target = Path.Combine(_root, $"{job.Id:N}.json");
        var temp = target + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await File.WriteAllTextAsync(temp, JsonSerializer.Serialize(job), cancellationToken);
            File.Move(temp, target, overwrite: true);
        }
        finally { if (File.Exists(temp)) File.Delete(temp); }
    }
    public async Task<CrawlJob?> GetAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var target = Path.Combine(_root, $"{id:N}.json");
        return File.Exists(target) ? JsonSerializer.Deserialize<CrawlJob>(await File.ReadAllTextAsync(target, cancellationToken)) : null;
    }
}
