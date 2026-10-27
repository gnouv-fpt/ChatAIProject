namespace BusinessObject.Entities;

public class ExamTemplateItem
{
    public Guid Id { get; set; }
    public Guid ExamTemplateId { get; set; }
    public Guid QuestionId { get; set; }
    public int OrderIndex { get; set; }
    public ExamTemplate ExamTemplate { get; set; } = null!;
    public TrafficQuestion Question { get; set; } = null!;
}
