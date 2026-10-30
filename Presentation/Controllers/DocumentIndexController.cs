using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Controllers;

[ApiController, Route("api/documents"), Authorize(Roles = nameof(UserRole.Admin))]
public sealed class DocumentIndexController(IDocumentIndexService service) : ControllerBase
{
    [HttpPost("{id:guid}/verify-and-index")]
    public async Task<IActionResult> Index(Guid id, VerifyDocumentRequestDto request, CancellationToken cancellationToken) =>
        Ok(await service.VerifyAndIndexAsync(id, request, cancellationToken));
}
