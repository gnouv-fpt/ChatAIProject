using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController, Authorize, Route("api/chats/{sessionId:guid}/attachments")]
public sealed class AttachmentsController(IAttachmentService attachments) : ControllerBase
{
    [HttpPost, RequestSizeLimit(6 * 1024 * 1024)]
    public async Task<ActionResult<AttachmentResponseDto>> Upload(Guid sessionId, IFormFile file, CancellationToken ct)
    {
        await using var stream = file.OpenReadStream();
        var result = await attachments.UploadAsync(User.GetUserId(), sessionId, file.ContentType, stream, ct);
        return CreatedAtAction(nameof(Get), new { sessionId, id = result.Id }, result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid sessionId, Guid id, CancellationToken ct)
    {
        var image = await attachments.ReadAsync(User.GetUserId(), sessionId, id, ct);
        Response.Headers.CacheControl = "no-store";
        Response.Headers.XContentTypeOptions = "nosniff";
        return File(image.Content, image.MimeType);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid sessionId, Guid id, CancellationToken ct)
    {
        await attachments.DeleteAsync(User.GetUserId(), sessionId, id, ct);
        return NoContent();
    }
}
