using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController]
[Route("api/learning")]
[Authorize]
[Produces("application/json")]
public class LearningController : ControllerBase
{
    private readonly ILearningProgressService _progressService;

    public LearningController(ILearningProgressService progressService)
    {
        _progressService = progressService;
    }

    /// <summary>
    /// Tiến độ của người dùng hiện tại trên từng bộ câu hỏi (đã xuất bản hoặc đã từng làm).
    /// </summary>
    [HttpGet("progress")]
    [ProducesResponseType<IReadOnlyList<BankProgressDto>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<BankProgressDto>>> GetOverview(CancellationToken cancellationToken)
    {
        return Ok(await _progressService.GetOverviewAsync(User.GetUserId(), cancellationToken));
    }

    /// <summary>
    /// Tiến độ chi tiết theo chủ đề của một phiên bản bộ câu hỏi.
    /// </summary>
    [HttpGet("progress/{bankId:guid}")]
    [ProducesResponseType<BankProgressDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<BankProgressDto>> GetBankProgress(Guid bankId, CancellationToken cancellationToken)
    {
        return await _progressService.GetBankProgressAsync(User.GetUserId(), bankId, cancellationToken);
    }

    /// <summary>
    /// Câu mà lần trả lời gần nhất bị sai.
    /// </summary>
    [HttpGet("progress/{bankId:guid}/wrong-questions")]
    [ProducesResponseType<PagedResultDto<QuestionProgressItemDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PagedResultDto<QuestionProgressItemDto>>> GetWrongQuestions(
        Guid bankId,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        return await _progressService.GetWrongQuestionsAsync(User.GetUserId(), bankId, pageIndex, pageSize, cancellationToken);
    }

    /// <summary>
    /// Câu chưa từng được chấm (chưa làm).
    /// </summary>
    [HttpGet("progress/{bankId:guid}/unseen-questions")]
    [ProducesResponseType<PagedResultDto<QuestionProgressItemDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PagedResultDto<QuestionProgressItemDto>>> GetUnseenQuestions(
        Guid bankId,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        return await _progressService.GetUnseenQuestionsAsync(User.GetUserId(), bankId, pageIndex, pageSize, cancellationToken);
    }

    /// <summary>
    /// Lịch sử các lượt học/thi của người dùng hiện tại.
    /// </summary>
    [HttpGet("history")]
    [ProducesResponseType<PagedResultDto<AttemptHistoryItemDto>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResultDto<AttemptHistoryItemDto>>> GetHistory(
        [FromQuery] Guid? bankId = null,
        [FromQuery] AttemptMode? mode = null,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        return await _progressService.GetHistoryAsync(User.GetUserId(), bankId, mode, pageIndex, pageSize, cancellationToken);
    }

    [HttpGet("bookmarks")]
    [ProducesResponseType<PagedResultDto<BookmarkItemDto>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResultDto<BookmarkItemDto>>> GetBookmarks(
        [FromQuery] Guid? bankId = null,
        [FromQuery] int pageIndex = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        return await _progressService.GetBookmarksAsync(User.GetUserId(), bankId, pageIndex, pageSize, cancellationToken);
    }

    [HttpPut("bookmarks/{questionId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> AddBookmark(Guid questionId, CancellationToken cancellationToken)
    {
        await _progressService.AddBookmarkAsync(User.GetUserId(), questionId, cancellationToken);
        return NoContent();
    }

    [HttpDelete("bookmarks/{questionId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveBookmark(Guid questionId, CancellationToken cancellationToken)
    {
        await _progressService.RemoveBookmarkAsync(User.GetUserId(), questionId, cancellationToken);
        return NoContent();
    }
}
