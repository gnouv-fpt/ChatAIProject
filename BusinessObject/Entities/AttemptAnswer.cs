namespace BusinessObject.Entities;

// One row per question in an attempt, created when the attempt starts (the question snapshot).
public class AttemptAnswer
{
    public Guid Id { get; set; }

    public Guid AttemptId { get; set; }

    public Guid QuestionId { get; set; }

    // 1-based order shown to this user.
    public int Position { get; set; }

    // Option IDs in display order; equals the original order when shuffling is not allowed.
    public List<string> OptionOrder { get; set; } = new();

    // Answer key copied at start so a later bank fix never changes the grading of this attempt.
    public List<string> CorrectOptionIds { get; set; } = new();

    public List<string> SelectedOptionIds { get; set; } = new();

    // Null until graded: set on answer in practice, and only at submit for exams.
    public bool? IsCorrect { get; set; }

    public bool IsFlagged { get; set; }

    public DateTime? AnsweredAt { get; set; }

    public LearningAttempt Attempt { get; set; } = null!;

    public Question Question { get; set; } = null!;
}
