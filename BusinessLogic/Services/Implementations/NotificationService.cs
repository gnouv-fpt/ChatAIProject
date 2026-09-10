using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class NotificationService : INotificationService
{
    private readonly INotificationRepository _notificationRepository;
    private readonly INotificationRealtimeNotifier _notificationRealtimeNotifier;
    private readonly ILogger<NotificationService> _logger;

    public NotificationService(
        INotificationRepository notificationRepository,
        INotificationRealtimeNotifier notificationRealtimeNotifier,
        ILogger<NotificationService> logger)
    {
        _notificationRepository = notificationRepository;
        _notificationRealtimeNotifier = notificationRealtimeNotifier;
        _logger = logger;
    }

    public async Task<NotificationSummaryDto> GetSummaryAsync(
        int userId,
        int take = 5,
        CancellationToken cancellationToken = default)
    {
        var unreadCount = await _notificationRepository.CountUnreadByUserAsync(userId, cancellationToken);
        var recent = await _notificationRepository.GetRecentByUserAsync(userId, take, cancellationToken);
        return new NotificationSummaryDto(unreadCount, recent.Select(MapNotification).ToList());
    }

    public async Task MarkAsReadAsync(
        int notificationId,
        int userId,
        CancellationToken cancellationToken = default)
    {
        await _notificationRepository.MarkAsReadAsync(notificationId, userId, cancellationToken);
        await NotifyUserSafelyAsync(userId, cancellationToken);
    }

    public async Task MarkAllAsReadAsync(
        int userId,
        CancellationToken cancellationToken = default)
    {
        await _notificationRepository.MarkAllAsReadAsync(userId, cancellationToken);
        await NotifyUserSafelyAsync(userId, cancellationToken);
    }

    public async Task NotifyUsersAsync(
        IReadOnlyCollection<int> recipientUserIds,
        string title,
        string message,
        string type,
        int? relatedSubjectId,
        CancellationToken cancellationToken = default)
    {
        var recipientIds = recipientUserIds
            .Where(userId => userId > 0)
            .Distinct()
            .ToList();
        if (recipientIds.Count == 0)
        {
            return;
        }

        var notifications = recipientIds.Select(userId => new Notification
        {
            UserId = userId,
            Title = title,
            Message = message,
            Type = type,
            RelatedSubjectId = relatedSubjectId,
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        }).ToList();

        await _notificationRepository.AddRangeAsync(notifications, cancellationToken);

        foreach (var userId in recipientIds)
        {
            await NotifyUserSafelyAsync(userId, cancellationToken);
        }
    }

    private async Task NotifyUserSafelyAsync(
        int userId,
        CancellationToken cancellationToken)
    {
        try
        {
            var summary = await GetSummaryAsync(userId, cancellationToken: cancellationToken);
            await _notificationRealtimeNotifier.NotifyAsync(userId, summary, cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "Could not broadcast notifications for user {UserId}", userId);
        }
    }

    private static NotificationDto MapNotification(Notification notification)
    {
        return new NotificationDto(
            notification.Id,
            notification.Title,
            notification.Message,
            notification.Type,
            notification.RelatedSubjectId,
            notification.IsRead,
            notification.CreatedAt,
            notification.ReadAt);
    }
}
