using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Presentation.Models;

namespace Presentation.Pages.Chat;

[Authorize]
public sealed class SessionsModel : AppPageModel
{
    private readonly IChatHistoryService _chatHistoryService;

    public SessionsModel(IChatHistoryService chatHistoryService)
    {
        _chatHistoryService = chatHistoryService;
    }

    public ChatSessionListViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(int? subjectId, CancellationToken cancellationToken)
    {
        var sessions = await _chatHistoryService.GetSessionsAsync(
            GetCurrentUserId(),
            subjectId,
            cancellationToken);

        ViewModel = new ChatSessionListViewModel
        {
            SubjectId = subjectId,
            Sessions = sessions.Select(MapSessionItem).ToList()
        };
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
}
