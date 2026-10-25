using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController]
[Route("api/reports")]
[Authorize]
[Produces("application/json")]
public class ReportsController : ControllerBase
{
    private readonly IUsageReportService _usageReportService;

    public ReportsController(IUsageReportService usageReportService)
    {
        _usageReportService = usageReportService;
    }

    /// <summary>
    /// Báo cáo sử dụng chat theo ngày (giờ Việt Nam). User chỉ xem của mình; Admin xem toàn hệ thống hoặc theo userId.
    /// </summary>
    [HttpGet("usage")]
    [ProducesResponseType<UsageReportDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<UsageReportDto>> GetUsage(
        [FromQuery] UsageReportQueryDto query,
        CancellationToken cancellationToken)
    {
        return await _usageReportService.GetUsageAsync(
            User.GetUserId(), User.IsInRole(nameof(UserRole.Admin)), query, cancellationToken);
    }
}
