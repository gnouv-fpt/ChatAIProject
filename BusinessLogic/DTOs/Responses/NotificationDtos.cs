namespace BusinessLogic.DTOs.Responses;

public sealed record NotificationDto(
    int Id,
    string Title,
    string Message,
    string Type,
    int? RelatedSubjectId,
    bool IsRead,
    DateTime CreatedAt,
    DateTime? ReadAt);

public sealed record NotificationSummaryDto(
    int UnreadCount,
    IReadOnlyList<NotificationDto> RecentNotifications);
