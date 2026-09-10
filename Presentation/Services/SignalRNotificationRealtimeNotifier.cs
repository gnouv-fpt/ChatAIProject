using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure.Interfaces;
using Microsoft.AspNetCore.SignalR;
using Presentation.Hubs;

namespace Presentation.Services;

public sealed class SignalRNotificationRealtimeNotifier : INotificationRealtimeNotifier
{
    private readonly IHubContext<NotificationHub> _hubContext;

    public SignalRNotificationRealtimeNotifier(IHubContext<NotificationHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public Task NotifyAsync(
        int userId,
        NotificationSummaryDto summary,
        CancellationToken cancellationToken = default)
    {
        return _hubContext.Clients
            .Group(NotificationGroups.ForUser(userId))
            .SendAsync("NotificationReceived", summary, cancellationToken);
    }
}
