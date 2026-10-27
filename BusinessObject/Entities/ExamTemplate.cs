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
}
