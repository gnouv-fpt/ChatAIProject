using System.Diagnostics.Metrics;
using DataAccess.Repositories.Interfaces;

namespace Presentation.Infrastructure;

public sealed class OutboxMetricsService(IServiceScopeFactory scopes, ILogger<OutboxMetricsService> logger) : BackgroundService
{
    private readonly Meter meter = new("ChatAIWeb.Chat.Outbox", "1.0");
    private long unpublished;
    private long unsettled;
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        meter.CreateObservableGauge("chat_outbox_pending", () => Interlocked.Read(ref unpublished));
        meter.CreateObservableGauge("chat_quota_unsettled", () => Interlocked.Read(ref unsettled));
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(15));
        try
        {
            do
            {
                try
                {
                    using var scope = scopes.CreateScope();
                    var repo = scope.ServiceProvider.GetRequiredService<IChatTurnRepository>();
                    var counts = await repo.GetOperationalCountsAsync(ct);
                    Interlocked.Exchange(ref unpublished, counts.Unpublished);
                    Interlocked.Exchange(ref unsettled, counts.Unsettled);
                }
                catch (Exception ex) when (!ct.IsCancellationRequested) { logger.LogWarning("Outbox metrics unavailable: {ExceptionType}", ex.GetType().Name); }
            } while (await timer.WaitForNextTickAsync(ct));
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { }
    }
    public override void Dispose() { meter.Dispose(); base.Dispose(); }
}
