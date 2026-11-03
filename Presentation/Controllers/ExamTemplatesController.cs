using Presentation.Infrastructure;
using BusinessLogic.Services.Implementations;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Controllers;

[ApiController, Route("api/exam-templates"), Authorize]
[ServiceModule("Content")]
public sealed class ExamTemplatesController(ExamTemplateService service) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellationToken) =>
        Ok(await service.ListAsync(false, cancellationToken));

    [HttpPost("import"), Authorize(Roles = nameof(UserRole.Admin))]
    public async Task<IActionResult> Import(ImportExamTemplateRequest request, CancellationToken cancellationToken) =>
        Ok(await service.ImportAsync(request, cancellationToken));

    [HttpGet("drafts"), Authorize(Roles = nameof(UserRole.Admin))]
    public async Task<IActionResult> Drafts(CancellationToken cancellationToken) =>
        Ok(await service.ListAsync(true, cancellationToken));

    [HttpPost("{code}/versions/{version:int}/publish"), Authorize(Roles = nameof(UserRole.Admin))]
    public async Task<IActionResult> Publish(string code, int version, CancellationToken cancellationToken) =>
        Ok(await service.PublishAsync(code, version, cancellationToken));
}
