using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Chat;

[Authorize]
public sealed class HistoryModel : AppPageModel
{
    private readonly IChatHistoryService _chatHistoryService;

    public HistoryModel(IChatHistoryService chatHistoryService)
    {
        _chatHistoryService = chatHistoryService;
    }

    public ChatHistoryViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(int sessionId, CancellationToken cancellationToken)
    {
        var history = await _chatHistoryService.GetHistoryAsync(
            sessionId,
            GetCurrentUserId(),
            cancellationToken);

        if (history is null)
        {
            return NotFound("Không tìm thấy phiên hội thoại hoặc bạn không có quyền truy cập.");
        }

        ViewModel = new ChatHistoryViewModel
        {
            Session = MapSessionItem(history.Session),
            Messages = MapMessages(history.Messages)
        };
        return Page();
    }

    private static ChatSessionListItemViewModel MapSessionItem(ChatSessionSummaryDto session)
    {
        return new ChatSessionListItemViewModel
        {
            Id = session.Id,
            SubjectId = session.SubjectId,
            SubjectName = session.SubjectName,
            Title = session.Title,
            CreatedAt = session.CreatedAt,
            UpdatedAt = session.UpdatedAt,
            MessageCount = session.MessageCount
        };
    }

    private static IReadOnlyList<ChatMessageViewModel> MapMessages(
        IReadOnlyList<ChatMessageDto> messages)
    {
        return messages
            .Select(message => new ChatMessageViewModel
            {
                Id = message.Id,
                Role = message.Role,
                Content = message.Content,
                ModelName = message.ModelName,
                CreatedAt = message.CreatedAt,
                Citations = message.Citations.Select(citation => new CitationViewModel
                {
                    CitationIndex = citation.CitationIndex,
                    DocumentTitle = citation.DocumentTitle,
                    PageNumber = citation.PageNumber,
                    SlideNumber = citation.SlideNumber,
                    ChunkIndex = citation.ChunkIndex,
                    SimilarityScore = citation.SimilarityScore,
                    Snippet = citation.Snippet
                }).ToList()
            })
            .ToList();
    }
}
