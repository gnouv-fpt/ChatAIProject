using BusinessLogic.Exams;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController]
[Authorize]
[Route("api/exam-notifications")]
public sealed class ExamNotificationsController(RedisNotificationInbox inbox) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ExamSubmittedEvent>>> Get(CancellationToken cancellationToken) =>
        Ok(await inbox.GetRecentAsync(User.GetUserId(), cancellationToken));
}
