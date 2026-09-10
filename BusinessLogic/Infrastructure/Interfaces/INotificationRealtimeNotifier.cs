using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Infrastructure.Interfaces;

public interface INotificationRealtimeNotifier
{
    Task NotifyAsync(
        int userId,
        NotificationSummaryDto summary,
        CancellationToken cancellationToken = default);
}
