namespace BusinessLogic.Infrastructure.Interfaces;

public interface ISubjectRealtimeNotifier
{
    Task NotifySubjectChangedAsync(
        int subjectId,
        string action,
        string message,
        IReadOnlyCollection<int> recipientUserIds,
        CancellationToken cancellationToken = default);

    Task NotifySubjectMembersChangedAsync(
        int subjectId,
        string action,
        string message,
        IReadOnlyCollection<int> recipientUserIds,
        CancellationToken cancellationToken = default);
}
