namespace BusinessObject.Entities;

// Submitted result is durable even after the custom exam expires in Redis.
public class ExamAttempt
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string ExamCode { get; set; } = null!;
    public int ExamVersion { get; set; }
    public int Score { get; set; }
    public bool IsPassed { get; set; }
    public int TimeSpentSeconds { get; set; }
    public string UserAnswersJson { get; set; } = "[]";
    public string ExamSnapshotJson { get; set; } = "{}";
    public string SubmissionHash { get; set; } = null!;
    public DateTime SubmittedAt { get; set; }
    public User User { get; set; } = null!;
}
