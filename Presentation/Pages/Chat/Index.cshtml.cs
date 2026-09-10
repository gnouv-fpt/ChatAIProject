using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Chat;

[Authorize]
public sealed class IndexModel : AppPageModel
{
    private readonly IChatbotService _chatbotService;
    private readonly IChatHistoryService _chatHistoryService;
    private readonly IDocumentService _documentService;

    public IndexModel(
        IChatbotService chatbotService,
        IChatHistoryService chatHistoryService,
        IDocumentService documentService)
    {
        _chatbotService = chatbotService;
        _chatHistoryService = chatHistoryService;
        _documentService = documentService;
    }

    [BindProperty]
    public ChatPageViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(
        int? subjectId,
        int? chatSessionId,
        CancellationToken cancellationToken)
    {
        await LoadPageAsync(subjectId, chatSessionId, cancellationToken);
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            await PopulateFormListsAsync(cancellationToken);
            return Page();
        }

        var response = await AskCoreAsync(ViewModel.Ask, cancellationToken);
        if (response.Succeeded && response.ChatSessionId.HasValue)
        {
            return RedirectToPage("/Chat/History", new { sessionId = response.ChatSessionId.Value });
        }

        ModelState.AddModelError(string.Empty, response.ErrorMessage ?? response.Answer);
        await PopulateFormListsAsync(cancellationToken);
        return Page();
    }

    private async Task LoadPageAsync(int? subjectId, int? chatSessionId, CancellationToken cancellationToken)
    {
        var userId = GetCurrentUserId();
        var subjects = await GetSubjectsAsync(cancellationToken);
        ViewModel = new ChatPageViewModel
        {
            ChatSessionId = chatSessionId,
            Subjects = subjects,
            Ask = new ChatAskViewModel
            {
                SubjectId = subjectId ?? 0,
                ChatSessionId = chatSessionId
            },
            RecentSessions = MapSessionItems(
                await _chatHistoryService.GetSessionsAsync(userId, subjectId, cancellationToken))
        };

        if (chatSessionId.HasValue)
        {
            var history = await _chatHistoryService.GetHistoryAsync(
                chatSessionId.Value,
                userId,
                cancellationToken);

            if (history is null)
            {
                ModelState.AddModelError(string.Empty, "Không tìm thấy phiên hội thoại hoặc bạn không có quyền truy cập.");
            }
            else
            {
                ViewModel.Ask.SubjectId = history.Session.SubjectId ?? subjectId ?? 0;
                ViewModel.Messages = MapMessages(history.Messages);
            }
        }
    }

    private async Task PopulateFormListsAsync(CancellationToken cancellationToken)
    {
        ViewModel.Subjects = await GetSubjectsAsync(cancellationToken);
        ViewModel.RecentSessions = MapSessionItems(
            await _chatHistoryService.GetSessionsAsync(GetCurrentUserId(), ViewModel.Ask.SubjectId, cancellationToken));
    }

    private async Task<ChatResponseDto> AskCoreAsync(
        ChatAskViewModel model,
        CancellationToken cancellationToken)
    {
        return await _chatbotService.AskAsync(
            new ChatRequestDto(
                model.SubjectId,
                model.Question,
                model.ChatSessionId,
                GetCurrentUserId()),
            cancellationToken);
    }

    private async Task<IReadOnlyList<SubjectOptionViewModel>> GetSubjectsAsync(CancellationToken cancellationToken)
    {
        var dtos = await _documentService.GetSubjectOptionsAsync(cancellationToken);
        return dtos.Select(s => new SubjectOptionViewModel
        {
            Id = s.Id,
            SubjectCode = s.SubjectCode,
            SubjectName = s.SubjectName
        }).ToList();
    }

    private static IReadOnlyList<ChatSessionListItemViewModel> MapSessionItems(
        IReadOnlyList<ChatSessionSummaryDto> sessions)
    {
        return sessions.Select(MapSessionItem).ToList();
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
                Citations = MapCitations(message.Citations)
            })
            .ToList();
    }

    private static IReadOnlyList<CitationViewModel> MapCitations(
        IReadOnlyList<CitationResponseDto> citations)
    {
        return citations
            .Select(citation => new CitationViewModel
            {
                CitationIndex = citation.CitationIndex,
                DocumentTitle = citation.DocumentTitle,
                PageNumber = citation.PageNumber,
                SlideNumber = citation.SlideNumber,
                ChunkIndex = citation.ChunkIndex,
                SimilarityScore = citation.SimilarityScore,
                Snippet = citation.Snippet
            })
            .ToList();
    }
}
