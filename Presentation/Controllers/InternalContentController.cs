using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Infrastructure;

namespace Presentation.Controllers;

[ServiceModule("Content")]
[ApiController]
[Route("internal/content")]
[Authorize(AuthenticationSchemes = "ContentService", Policy = "ContentRead")]
public sealed class InternalContentController(IContentChunkService chunks) : ControllerBase
{
    [HttpPost("chunks")]
    public Task<IReadOnlyList<ContentChunkSnapshotDto>> GetChunks(Guid[] ids, CancellationToken ct) =>
        chunks.GetAsync(ids, ct);
}
