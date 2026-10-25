namespace BusinessObject.Entities;

public class QuestionBookmark
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid QuestionId { get; set; }

    public DateTime CreatedAt { get; set; }

    public User User { get; set; } = null!;

    public Question Question { get; set; } = null!;
}
