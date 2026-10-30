using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController, Route("api/admin/question-banks"), Authorize(Roles = nameof(UserRole.Admin))]
public sealed class AdminQuestionBanksController(IQuestionBankService service) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellationToken) => Ok(await service.ListAsync(true, cancellationToken));

    [HttpPost("import"), RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> Import(ImportQuestionBankRequestDto request, CancellationToken cancellationToken) =>
        Ok(await service.ImportAsync(request.Bank, User.GetUserId(), cancellationToken));

    [HttpGet("{id:guid}/versions/{version}/preview")]
    public async Task<IActionResult> Preview(Guid id, string version, CancellationToken cancellationToken) =>
        Ok(await service.PreviewAsync(id, version, cancellationToken));

    [HttpPost("{id:guid}/versions/{version}/publish")]
    public async Task<IActionResult> Publish(Guid id, string version, PublishBankRequestDto request, CancellationToken cancellationToken) =>
        Ok(await service.PublishAsync(id, version, request, cancellationToken));
}
