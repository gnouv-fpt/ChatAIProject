namespace BusinessLogic.Exams;

// IDs remain opaque until the shared P0 schema contract fixes their physical types.
public sealed record ExamOption(string Id, string Text);

public sealed record BankQuestion(
    string Id,
    string Version,
    string Text,
    IReadOnlyList<ExamOption> Options,
    string CorrectOptionId);

public sealed record CreateCustomExam(string CategoryId, string BankVersion, int QuestionCount, int DurationMinutes);

public sealed record ExamQuestion(string Id, string Text, IReadOnlyList<ExamOption> Options);

public sealed record CustomExamView(
    Guid ExamId,
    string BankVersion,
    DateTimeOffset DeadlineUtc,
    long Revision,
    string Status,
    IReadOnlyList<ExamQuestion> Questions,
    IReadOnlyDictionary<string, string> Answers);

public sealed record ExamScore(Guid AttemptId, Guid ExamId, int Correct, int Total, DateTimeOffset SubmittedAtUtc);

public sealed record SaveExamResult(
    Guid AttemptId,
    Guid ExamId,
    Guid UserId,
    string BankVersion,
    DateTimeOffset SubmittedAtUtc,
    int Correct,
    int Total,
    IReadOnlyList<GradedQuestion> Questions);

public sealed record GradedQuestion(
    string QuestionId,
    string Version,
    string Text,
    IReadOnlyList<ExamOption> Options,
    string CorrectOptionId,
    string? SelectedOptionId);

// Content service must return server-only keys. Never expose BankQuestion to the exam client.
public interface IExamQuestionSource
{
    Task<IReadOnlyList<BankQuestion>> GetQuestionsAsync(
        string categoryId, string bankVersion, int count, CancellationToken cancellationToken);
}

// User service must enforce a unique AttemptId and return success for an identical retry.
public interface IExamResultSink
{
    Task SaveAsync(SaveExamResult result, CancellationToken cancellationToken);
}

public interface ICustomExamStore
{
    Task<bool> CreateAsync(StoredExam exam, TimeSpan ttl, CancellationToken cancellationToken);
    Task<StoredExam?> ReadAsync(Guid examId, CancellationToken cancellationToken);
    Task<bool> CompareExchangeAsync(StoredExam original, StoredExam updated, CancellationToken cancellationToken);
}

public sealed record StoredQuestion(
    string Id, string Version, string Text, IReadOnlyList<ExamOption> Options, string CorrectOptionId);

public sealed record StoredExam(
    Guid ExamId,
    Guid AttemptId,
    Guid UserId,
    string BankVersion,
    DateTimeOffset CreatedAtUtc,
    DateTimeOffset DeadlineUtc,
    long Revision,
    string Status,
    DateTimeOffset? SubmittedAtUtc,
    IReadOnlyList<StoredQuestion> Questions,
    IReadOnlyDictionary<string, string> Answers);
