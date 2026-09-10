using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Presentation.Hubs;

[Authorize]
public sealed class NotificationHub : Hub
{
    public Task JoinNotifications()
    {
        var userIdValue = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(userIdValue, out var userId) || userId <= 0)
        {
            throw new HubException("Người dùng không hợp lệ.");
        }

        return Groups.AddToGroupAsync(Context.ConnectionId, NotificationGroups.ForUser(userId));
    }
}
