using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Controllers;

[ApiController, Route("api/admin/content-previews"), Authorize(Roles = nameof(UserRole.Admin))]
public sealed class ContentPreviewsController(IContentManifestService manifests, ILegalSourcePreviewService sources) : ControllerBase
{
    [HttpGet("capabilities")]
    public ActionResult<ContentCapabilitiesDto> Capabilities() => Ok(manifests.GetCapabilities());

    [HttpPost("question-banks"), RequestSizeLimit(10 * 1024 * 1024)]
    public ActionResult<ContentManifestPreviewDto> PreviewBank(ContentManifestRequestDto request) => Ok(manifests.Preview(request));

    [HttpPost("legal-source")]
    public async Task<ActionResult<LegalSourceEvidenceDto>> PreviewLegalSource(CrawlPreviewRequestDto request, CancellationToken cancellationToken) =>
        Ok(await sources.PreviewAsync(request.SourceUrl, cancellationToken));
}
