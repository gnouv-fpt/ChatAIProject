using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Presentation.Hubs;

[Authorize(Roles = "Admin,Teacher")]
public sealed class SubjectManagementHub : Hub
{
    public Task JoinSubjectIndex()
    {
        if (Context.User?.IsInRole("Admin") == true)
        {
            return Groups.AddToGroupAsync(Context.ConnectionId, SubjectManagementGroups.Admins);
        }

        var userIdValue = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (Context.User?.IsInRole("Teacher") == true
            && int.TryParse(userIdValue, out var userId)
            && userId > 0)
        {
            return Groups.AddToGroupAsync(Context.ConnectionId, SubjectManagementGroups.ForUser(userId));
        }

        throw new HubException("Người dùng không hợp lệ.");
    }

    [Authorize(Roles = "Admin")]
    public Task JoinSubjectMembers(int subjectId)
    {
        if (subjectId <= 0)
        {
            throw new HubException("Môn học không hợp lệ.");
        }

        return Groups.AddToGroupAsync(Context.ConnectionId, SubjectManagementGroups.ForMembers(subjectId));
    }
}
