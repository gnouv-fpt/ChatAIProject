using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Chat;

[Authorize]
public sealed class AskModel : AppPageModel
{
    private readonly IChatbotService _chatbotService;

    public AskModel(IChatbotService chatbotService)
    {
        _chatbotService = chatbotService;
    }

    [BindProperty]
    public ChatPageViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new
            {
                succeeded = false,
                errorMessage = "Vui lòng kiểm tra lại thông tin câu hỏi."
            });
        }

        var response = await _chatbotService.AskAsync(
            new ChatRequestDto(
                ViewModel.Ask.SubjectId,
                ViewModel.Ask.Question,
                ViewModel.Ask.ChatSessionId,
                GetCurrentUserId()),
            cancellationToken);

        if (!response.Succeeded)
        {
            return BadRequest(response);
        }

        return new JsonResult(response);
    }
}
