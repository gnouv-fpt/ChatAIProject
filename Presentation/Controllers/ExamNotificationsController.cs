using BusinessLogic.Exams;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;
using Presentation.Infrastructure;

namespace Presentation.Controllers;

[ApiController]
[Authorize]
[Route("api/exam-notifications")]
[ServiceModule("User")]
public sealed class ExamNotificationsController(ExamResultService results) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ExamSubmittedEvent>>> Get(CancellationToken cancellationToken) =>
        Ok(await results.GetRecentNotificationsAsync(User.GetUserId(), cancellationToken));
}
