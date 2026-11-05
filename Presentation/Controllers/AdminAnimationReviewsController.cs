using BusinessLogic.Exams;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Infrastructure;

namespace Presentation.Controllers;

[ApiController]
[ServiceModule("User")]
[Route("api/admin/animation-reviews")]
[Authorize(Roles = nameof(UserRole.Admin))]
public sealed class AdminAnimationReviewsController(AdminAnimationReviewService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AdminAnimationSummary>>> GetAll(CancellationToken ct) =>
        Ok(await service.GetAllAsync(ct));

    [HttpGet("{number:int}")]
    public async Task<ActionResult<AdminAnimationPayload>> Get(int number, CancellationToken ct) =>
        Ok(await service.GetAsync(number, ct));
}
