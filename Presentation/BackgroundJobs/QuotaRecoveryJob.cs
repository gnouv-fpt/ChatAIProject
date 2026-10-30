using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Interfaces;

namespace Presentation.BackgroundJobs;

// Periodically frees expired reservations and settles completed turns whose event was never consumed.
public sealed class QuotaRecoveryJob : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly QuotaSettings _settings;
    private readonly ILogger<QuotaRecoveryJob> _logger;

    public QuotaRecoveryJob(IServiceProvider serviceProvider, QuotaSettings settings, ILogger<QuotaRecoveryJob> logger)
    {
        _serviceProvider = serviceProvider;
        _settings = settings;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(Math.Max(5, _settings.RecoveryIntervalSeconds)));
        try
        {
            do
            {
                try
                {
                    using var scope = _serviceProvider.CreateScope();
                    await scope.ServiceProvider.GetRequiredService<IQuotaService>().RecoverAsync(stoppingToken);
                }
                catch (Exception exception) when (exception is not OperationCanceledException)
                {
                    _logger.LogError(exception, "Quota recovery failed; retrying next interval");
                }
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
        }
    }
}
