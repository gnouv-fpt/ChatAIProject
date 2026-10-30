using BusinessLogic.Services.Interfaces;

namespace WorkerService;

// Calls Content service on startup and each Vietnam midnight; Content owns all persistence.
public sealed class ContentMaintenanceWorker(IServiceScopeFactory scopes, ILogger<ContentMaintenanceWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById(OperatingSystem.IsWindows() ? "SE Asia Standard Time" : "Asia/Ho_Chi_Minh");
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopes.CreateScope();
                await scope.ServiceProvider.GetRequiredService<IContentMaintenanceService>().RunAsync(stoppingToken);
                var local = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, zone);
                var next = TimeZoneInfo.ConvertTimeToUtc(local.Date.AddDays(1), zone);
                await Task.Delay(next - DateTime.UtcNow, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception exception)
            {
                logger.LogError(exception, "Content maintenance failed; retrying in one minute");
                try { await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken); }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            }
        }
    }
}
