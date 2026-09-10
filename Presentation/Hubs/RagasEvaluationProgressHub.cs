using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Presentation.Hubs;

[Authorize(Roles = "Admin")]
public sealed class RagasEvaluationProgressHub : Hub
{
    public Task JoinEvaluation(string evaluationId)
    {
        var userIdValue = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(userIdValue, out var userId)
            || userId <= 0
            || !RagasEvaluationProgressGroups.IsValidEvaluationId(evaluationId))
        {
            throw new HubException("Phiên đánh giá không hợp lệ.");
        }

        return Groups.AddToGroupAsync(
            Context.ConnectionId,
            RagasEvaluationProgressGroups.ForUserEvaluation(userId, evaluationId));
    }
}
