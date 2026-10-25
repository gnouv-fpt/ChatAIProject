namespace BusinessObject.Entities;

public class ExamTemplate
{
    public Guid Id { get; set; }

    public Guid BankId { get; set; }

    public string Code { get; set; } = null!;

    public string Name { get; set; } = null!;

    public int QuestionCount { get; set; }

    public int DurationMinutes { get; set; }

    public int PassingScore { get; set; }

    // When true, answering any critical question wrong fails the exam regardless of score.
    public bool FailOnCriticalWrong { get; set; }

    // Topic quotas as JSON, e.g. {"Biển báo": 8}; null means no per-topic quota.
    public string? TopicDistribution { get; set; }

    // Set for a fixed, pre-built exam; empty means questions are drawn by the profile.
    public List<Guid> FixedQuestionIds { get; set; } = new();

    public string? SourceName { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }

    public QuestionBank Bank { get; set; } = null!;
}
