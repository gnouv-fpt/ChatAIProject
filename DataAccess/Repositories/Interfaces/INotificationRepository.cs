using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface INotificationRepository
{
    Task AddRangeAsync(IEnumerable<Notification> notifications, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Notification>> GetRecentByUserAsync(
        int userId,
        int take,
        CancellationToken cancellationToken = default);

    Task<int> CountUnreadByUserAsync(int userId, CancellationToken cancellationToken = default);

    Task MarkAsReadAsync(int notificationId, int userId, CancellationToken cancellationToken = default);

    Task MarkAllAsReadAsync(int userId, CancellationToken cancellationToken = default);
}
