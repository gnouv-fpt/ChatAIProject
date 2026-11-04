using Presentation.Infrastructure;
using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using BusinessLogic.Services.Implementations;
using BusinessObject.Entities;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController, Route("api/admin/question-banks"), Authorize(Roles = nameof(UserRole.Admin))]
[ServiceModule("Content")]
public sealed class AdminQuestionBanksController(IQuestionBankService service, ContentBankImportService imports) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellationToken) => Ok(await service.ListAsync(true, cancellationToken));

    [HttpPost("import"), RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> Import(ImportQuestionBankRequestDto request, CancellationToken cancellationToken) =>
        Ok(await imports.ImportAsync(request, User.GetUserId(), cancellationToken));

    [HttpGet("{id:guid}/versions/{version}/preview")]
    public async Task<IActionResult> Preview(Guid id, string version, CancellationToken cancellationToken) =>
        Ok(await service.PreviewAsync(id, version, cancellationToken));

    [HttpPost("{id:guid}/versions/{version}/publish")]
    public async Task<IActionResult> Publish(Guid id, string version, PublishBankRequestDto request, CancellationToken cancellationToken) =>
        Ok(await service.PublishAsync(id, version, request, cancellationToken));
}
