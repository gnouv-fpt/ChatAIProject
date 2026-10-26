using BusinessLogic.Services.Interfaces;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Controllers;

[ApiController, Route("api/documents/crawl-jobs"), Authorize(Roles = nameof(UserRole.Admin))]
public sealed class CrawlJobsController(ICrawlJobService service) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Run(CancellationToken cancellationToken) => Ok(await service.RunAsync(cancellationToken));
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken cancellationToken) => Ok(await service.GetAsync(id, cancellationToken));
}
