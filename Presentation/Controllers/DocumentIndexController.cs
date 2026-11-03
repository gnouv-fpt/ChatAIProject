using Presentation.Infrastructure;
using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Controllers;

[ApiController, Route("api/documents"), Authorize(Roles = nameof(UserRole.Admin))]
[ServiceModule("Content")]
public sealed class DocumentIndexController(IDocumentIndexService service, BusinessLogic.Services.Implementations.LegalCorpusService corpus,
    BusinessLogic.Services.Implementations.LegalCorpusExtensionService extension) : ControllerBase
{
    [HttpPost("import-reviewed-source")]
    public async Task<IActionResult> Import(BusinessLogic.Services.Implementations.ImportLegalCorpusRequest request, CancellationToken cancellationToken) =>
        Ok(await corpus.ImportAsync(request, cancellationToken));

    [HttpPost("import-reviewed-capture"), RequestSizeLimit(3 * 1024 * 1024)]
    public async Task<IActionResult> ImportCapture(BusinessLogic.Services.Implementations.ImportCapturedLegalCorpusRequest request, CancellationToken cancellationToken) =>
        Ok(await corpus.ImportCapturedAsync(request, cancellationToken));

    [HttpPost("extend-reviewed-capture"), RequestSizeLimit(3 * 1024 * 1024)]
    public async Task<IActionResult> ExtendCapture(BusinessLogic.Services.Implementations.ExtendReviewedCorpusRequest request, CancellationToken cancellationToken) =>
        Ok(await extension.ExtendAsync(request, cancellationToken));

    [HttpPost("{id:guid}/verify-and-index")]
    public async Task<IActionResult> Index(Guid id, VerifyDocumentRequestDto request, CancellationToken cancellationToken) =>
        Ok(await service.VerifyAndIndexAsync(id, request, cancellationToken));
}
