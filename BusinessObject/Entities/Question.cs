namespace BusinessObject.Entities;

public class Question
{
    public Guid Id { get; set; }

    public Guid BankId { get; set; }

    // 1-based position inside the bank version, used for range selection (e.g. 1-50).
    public int Number { get; set; }

    // Stable identifier from the source bank; the same question keeps it across versions.
    public string ExternalId { get; set; } = null!;

    public string Content { get; set; } = null!;

    public string? ImagePath { get; set; }

    public string Topic { get; set; } = null!;

    // "Câu điểm liệt": answering it wrong fails an exam when the profile says so.
    public bool IsCritical { get; set; }

    // False when options reference each other ("cả A và B") or labels drawn on the image.
    public bool AllowOptionShuffle { get; set; }

    public List<QuestionOption> Options { get; set; } = new();

    public List<string> CorrectOptionIds { get; set; } = new();

    public string? Explanation { get; set; }

    public string? LegalReference { get; set; }

    public string ContentHash { get; set; } = null!;

    public QuestionBank Bank { get; set; } = null!;
}

// Stored as JSON inside Questions.Options.
public class QuestionOption
{
    // Stable option ID ("A", "B", ...); answer keys and permutations refer to it, never to display order.
    public string OptionId { get; set; } = null!;

    public string Text { get; set; } = null!;
}
