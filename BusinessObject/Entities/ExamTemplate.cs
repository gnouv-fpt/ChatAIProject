namespace BusinessObject.Entities;

public class ExamTemplate
{
    public Guid Id { get; set; }
    public string ExamCode { get; set; } = null!;
    public int Version { get; set; }
    public string Title { get; set; } = null!;
    public int DurationMinutes { get; set; }
    public int PassingScore { get; set; }
    public bool IsPublished { get; set; }
    public DateTime CreatedAt { get; set; }
    public ICollection<ExamTemplateItem> Items { get; set; } = new List<ExamTemplateItem>();

    // Kept for the legacy context and its existing migrations.
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public Guid BankId { get; set; }
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string Code { get; set; } = null!;
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string Name { get; set; } = null!;
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public int QuestionCount { get; set; }
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public bool FailOnCriticalWrong { get; set; }
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string? TopicDistribution { get; set; }
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public List<Guid> FixedQuestionIds { get; set; } = new();
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string? SourceName { get; set; }
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public bool IsActive { get; set; } = true;
    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public QuestionBank Bank { get; set; } = null!;
}
