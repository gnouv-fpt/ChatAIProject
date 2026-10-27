namespace BusinessObject.Entities;

public class TrafficQuestionCategory
{
    public Guid Id { get; set; }
    public string Type { get; set; } = null!;
    public string SubCategoryCode { get; set; } = null!;
    public string Name { get; set; } = null!;
    public ICollection<TrafficQuestion> Questions { get; set; } = new List<TrafficQuestion>();
}
