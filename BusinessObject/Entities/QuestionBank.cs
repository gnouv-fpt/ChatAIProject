namespace BusinessObject.Entities;

// Immutable content package; persistence does not add EF tables.
public sealed record QuestionBank
{
    public Guid Id { get; init; }
    public string Version { get; init; } = "";
    public string Title { get; init; } = "";
    public string SourceUrl { get; init; } = "";
    public string SourceDescription { get; init; } = "";
    public ExamProfile Profile { get; init; } = new();
    public List<BankQuestion> Questions { get; init; } = [];
}

public sealed record ExamProfile
{
    public string Id { get; init; } = "";
    public string Version { get; init; } = "";
    public string SourceUrl { get; init; } = "";
    public int QuestionCount { get; init; }
    public int DurationSeconds { get; init; }
    public int PassCount { get; init; }
    public bool FailOnCriticalWrong { get; init; }
}

public sealed record BankQuestion
{
    public Guid Id { get; init; }
    public int Number { get; init; }
    public string Topic { get; init; } = "";
    public string Text { get; init; } = "";
    public string Explanation { get; init; } = "";
    public string SourceUrl { get; init; } = "";
    public bool IsCritical { get; init; }
    // Explicit opt-in; referenced option labels/images must never be shuffled implicitly.
    public bool AllowOptionShuffle { get; init; }
    public List<QuestionOption> Options { get; init; } = [];
    public List<string> CorrectOptionIds { get; init; } = [];
    public List<QuestionAsset> Assets { get; init; } = [];
}

public sealed record QuestionOption(string Id, string Text);
public sealed record QuestionAsset(string Id, string Url, string Sha256, string MimeType, string AltText);

public sealed record QuestionBankPackage(QuestionBank Bank, string Hash, DateTime ImportedAt,
    Guid ImportedBy, bool IsPublished = false, DateTime? PublishedAt = null);
