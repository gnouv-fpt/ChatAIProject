namespace BusinessLogic.DTOs.Requests;

// Dates are Vietnam calendar days (UTC+7), both ends inclusive.
public sealed class UsageReportQueryDto
{
    public DateOnly? From { get; set; }

    public DateOnly? To { get; set; }

    // Admin: report for this user (all users when empty). A normal user asking for someone else gets 403.
    public Guid? UserId { get; set; }
}
