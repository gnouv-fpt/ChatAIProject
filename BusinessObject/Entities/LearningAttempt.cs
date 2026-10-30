using BusinessObject.Enums;

namespace BusinessObject.Entities;

public class LearningAttempt
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    // Points at one immutable bank version; never re-resolved to the latest version.
    public Guid BankId { get; set; }

    public Guid? ExamTemplateId { get; set; }

    public AttemptMode Mode { get; set; }

    public AttemptStatus Status { get; set; } = AttemptStatus.InProgress;

    // Selection criteria and exam profile copied at start (JSON) so grading never reads a changed template.
    public string? SelectionCriteria { get; set; }

    public string? ProfileSnapshot { get; set; }

    public int Seed { get; set; }

    public int QuestionCount { get; set; }

    public DateTime StartedAt { get; set; }

    // Server-side deadline for exams; reloading the client never resets it.
    public DateTime? DeadlineAt { get; set; }

    public DateTime? SubmittedAt { get; set; }

    // Client key of the submit call; a retry with the same key returns the stored result.
    public Guid? SubmitRequestId { get; set; }

    public int? CorrectCount { get; set; }

    public int? WrongCount { get; set; }

    public int? UnansweredCount { get; set; }

    public int? Score { get; set; }

    public bool? IsPassed { get; set; }

    public string? FailReason { get; set; }

    // Optimistic concurrency: two concurrent submits cannot both grade the attempt.
    public byte[] RowVersion { get; set; } = null!;

    public User User { get; set; } = null!;

    public QuestionBank Bank { get; set; } = null!;

    public ExamTemplate? ExamTemplate { get; set; }

    public ICollection<AttemptAnswer> Answers { get; set; } = new List<AttemptAnswer>();
}
