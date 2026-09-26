using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController]
[Route("api/chats")]
[Authorize]
public class ChatsController : ControllerBase
{
    private readonly IChatbotService _chatService;

    public ChatsController(IChatbotService chatService)
    {
        _chatService = chatService;
    }

    /// <summary>
    /// Tạo phiên hỏi đáp mới về luật giao thông đường bộ.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(ChatSessionResponseDto), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ChatSessionResponseDto>> Create(
        [FromBody] CreateChatSessionRequest request,
        CancellationToken cancellationToken)
    {
        var session = await _chatService.CreateSessionAsync(User.GetUserId(), request, cancellationToken);
        return CreatedAtAction(nameof(GetDetail), new { sessionId = session.Id }, session);
    }

    /// <summary>
    /// Lấy danh sách các phiên hỏi đáp của người dùng hiện tại (hỗ trợ phân trang và tìm kiếm).
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResultDto<ChatSessionResponseDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<PagedResultDto<ChatSessionResponseDto>>> GetList(
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] string? search = null,
        CancellationToken cancellationToken = default)
    {
        var result = await _chatService.GetSessionsAsync(User.GetUserId(), pageIndex, pageSize, search, cancellationToken);
        return Ok(result);
    }

    /// <summary>
    /// Lấy chi tiết phiên hỏi đáp và toàn bộ lịch sử tin nhắn cùng trích dẫn pháp lý.
    /// </summary>
    [HttpGet("{sessionId:guid}")]
    [ProducesResponseType(typeof(ChatSessionDetailResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ChatSessionDetailResponseDto>> GetDetail(
        Guid sessionId,
        CancellationToken cancellationToken)
    {
        var session = await _chatService.GetSessionDetailAsync(User.GetUserId(), sessionId, cancellationToken);
        return Ok(session);
    }

    /// <summary>
    /// Gửi câu hỏi pháp luật giao thông và nhận phản hồi AI RAG real-time kèm trích dẫn (Citations).
    /// </summary>
    [HttpPost("{sessionId:guid}/messages")]
    [ProducesResponseType(typeof(ChatMessageResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ChatMessageResponseDto>> SendMessage(
        Guid sessionId,
        [FromBody] SendMessageRequest request,
        CancellationToken cancellationToken)
    {
        var message = await _chatService.SendMessageAsync(User.GetUserId(), sessionId, request, cancellationToken);
        return Ok(message);
    }

    /// <summary>
    /// Xóa phiên hỏi đáp.
    /// </summary>
    [HttpDelete("{sessionId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Delete(
        Guid sessionId,
        CancellationToken cancellationToken)
    {
        await _chatService.DeleteSessionAsync(User.GetUserId(), sessionId, cancellationToken);
        return NoContent();
    }
}
