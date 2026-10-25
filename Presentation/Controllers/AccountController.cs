using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController]
[Route("api/account")]
[Authorize]
[Produces("application/json")]
public class AccountController : ControllerBase
{
    private readonly IQuotaService _quotaService;

    public AccountController(IQuotaService quotaService)
    {
        _quotaService = quotaService;
    }

    /// <summary>
    /// Số dư token, phần đang giữ chỗ cho câu hỏi chưa quyết toán và phần còn dùng được.
    /// </summary>
    [HttpGet("quota")]
    [ProducesResponseType<QuotaSnapshotDto>(StatusCodes.Status200OK)]
    public async Task<ActionResult<QuotaSnapshotDto>> GetQuota(CancellationToken cancellationToken)
    {
        return await _quotaService.GetSnapshotAsync(User.GetUserId(), cancellationToken);
    }
}
