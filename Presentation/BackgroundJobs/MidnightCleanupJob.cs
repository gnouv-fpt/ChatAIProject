using BusinessObject.Enums;
using DataAccess;
using Microsoft.EntityFrameworkCore;

namespace Presentation.BackgroundJobs;

public sealed class MidnightCleanupJob : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<MidnightCleanupJob> _logger;

    public MidnightCleanupJob(IServiceProvider serviceProvider, ILogger<MidnightCleanupJob> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                var now = DateTime.Now;
                var nextRun = DateTime.Today.AddDays(1);
                var delay = nextRun - now;

                _logger.LogInformation("Midnight Job hẹn giờ chạy sau: {Delay}", delay);
                await Task.Delay(delay, stoppingToken);
                await RunCleanupAsync(stoppingToken);
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            _logger.LogInformation("Midnight Job đã dừng.");
        }
    }

    private async Task RunCleanupAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ChatAIWebDbContext>();
            var now = DateTime.UtcNow;

            var expiredDocuments = await db.LegalDocuments
                .Where(document => document.IsActive &&
                    document.ExpirationDate != null &&
                    document.ExpirationDate <= now)
                .ToListAsync(cancellationToken);

            foreach (var document in expiredDocuments)
            {
                document.IsActive = false;
                document.VerificationStatus = VerificationStatus.Outdated;
            }

            var emptySessions = await db.ChatSessions
                .Where(session => !session.Messages.Any() && session.CreatedAt < now.AddDays(-1))
                .ToListAsync(cancellationToken);

            db.ChatSessions.RemoveRange(emptySessions);
            await db.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Midnight Job hoàn thành quét hiệu lực và dọn session.");
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Lỗi xảy ra trong Midnight Cron Job");
        }
    }
}