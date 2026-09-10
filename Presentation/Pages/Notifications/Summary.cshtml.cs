using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Pages.Notifications;

[Authorize]
public sealed class SummaryModel : AppPageModel
{
    private readonly INotificationService _notificationService;

    public SummaryModel(INotificationService notificationService)
    {
        _notificationService = notificationService;
    }

    public NotificationSummaryDto Summary { get; private set; } = new(0, []);

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        Summary = await _notificationService.GetSummaryAsync(GetCurrentUserId(), cancellationToken: cancellationToken);
    }

    public async Task<IActionResult> OnPostMarkReadAsync(int id, CancellationToken cancellationToken)
    {
        await _notificationService.MarkAsReadAsync(id, GetCurrentUserId(), cancellationToken);
        return new JsonResult(new { succeeded = true });
    }

    public async Task<IActionResult> OnPostMarkAllReadAsync(CancellationToken cancellationToken)
    {
        await _notificationService.MarkAllAsReadAsync(GetCurrentUserId(), cancellationToken);
        return new JsonResult(new { succeeded = true });
    }
}
