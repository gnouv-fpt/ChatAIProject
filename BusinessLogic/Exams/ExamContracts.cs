using System.Text.Json;

namespace BusinessLogic.Exams;

// IDs remain opaque until the shared P0 schema contract fixes their physical types.
public sealed record ExamOption(string Id, string Text);
public sealed record ExamAsset(string Id, string Url, string AltText, string Sha256, string MimeType);

public sealed record BankQuestion(
    string Id,
    string Version,
    string Text,
    IReadOnlyList<ExamOption> Options,
    string CorrectOptionId,
    bool CanShuffleOptions = false, Guid BankId = default, bool IsCritical = false,
    int PassingScore = 0, bool FailOnCriticalWrong = false, IReadOnlyList<ExamAsset>? Assets = null,
    string? Explanation = null, string? ExplanationAnimationUrl = null);

public sealed record CreateCustomExam(string CategoryId, string BankVersion, int QuestionCount, int DurationMinutes);
public sealed record CreateTemplateExam(string ExamCode, int Version);
public sealed record TemplateQuestionSet(string BankVersion, int DurationMinutes, int PassingScore,
    IReadOnlyList<BankQuestion> Questions);

public sealed record ExamQuestion(string Id, string Text, IReadOnlyList<ExamOption> Options, IReadOnlyList<ExamAsset>? Assets = null);

public sealed record CustomExamView(
    Guid ExamId,
    string BankVersion,
    DateTimeOffset DeadlineUtc,
    long Revision,
    string Status,
    IReadOnlyList<ExamQuestion> Questions,
    IReadOnlyDictionary<string, string> Answers, Guid BankId = default, int PassingScore = 0, bool FailOnCriticalWrong = false,
    Guid? AttemptId = null);

public sealed record ExamScore(Guid AttemptId, Guid ExamId, int Correct, int Total, DateTimeOffset SubmittedAtUtc);

public sealed record ExamAttemptReview(Guid AttemptId, Guid ExamId, Guid BankId, string BankVersion,
    int Correct, int Total, bool IsPassed, DateTimeOffset SubmittedAtUtc,
    IReadOnlyList<GradedQuestion> Questions, IReadOnlyList<string> AnimationAllowedHosts, string? LocalAssetOrigin = null);

public sealed record ExamAnimationImage(string Url, int Width, int Height);
public sealed record ExamAnimationSource(int Number, IReadOnlyList<ExamAnimationImage> Images, JsonElement Recipe);
public sealed record ExamAnimationPayload(string AssetBaseUrl, int Number,
    IReadOnlyList<ExamAnimationImage> Images, JsonElement Recipe);

public interface IExamAnimationCatalog
{
    Task<ExamAnimationSource?> GetAsync(int number, CancellationToken cancellationToken);
}

public sealed record SaveExamResult(
    Guid AttemptId,
    Guid ExamId,
    Guid UserId,
    string BankVersion,
    DateTimeOffset SubmittedAtUtc,
    int Correct,
    int Total,
    IReadOnlyList<GradedQuestion> Questions, Guid BankId = default, DateTimeOffset? StartedAtUtc = null,
    DateTimeOffset? DeadlineUtc = null, int PassingScore = 0, bool FailOnCriticalWrong = false,
    string? TemplateCode = null, int? TemplateVersion = null);

public sealed record GradedQuestion(
    string QuestionId,
    string Version,
    string Text,
    IReadOnlyList<ExamOption> Options,
    string CorrectOptionId,
    string? SelectedOptionId, bool IsCritical = false, IReadOnlyList<ExamAsset>? Assets = null,
    string? Explanation = null, string? ExplanationAnimationUrl = null);

// Content service must return server-only keys. Never expose BankQuestion to the exam client.
public interface IExamQuestionSource
{
    Task<IReadOnlyList<BankQuestion>> GetQuestionsAsync(
        string categoryId, string bankVersion, int count, CancellationToken cancellationToken);
    Task<TemplateQuestionSet> GetTemplateAsync(string code, int version, CancellationToken cancellationToken) =>
        throw new NotSupportedException("Template questions are not configured.");
}

// User service must enforce a unique AttemptId and return success for an identical retry.
public interface IExamResultSink
{
    Task SaveAsync(SaveExamResult result, CancellationToken cancellationToken);
}

public sealed record ExamSubmittedEvent(
    Guid EventId,
    int SchemaVersion,
    Guid EntityId,
    long EntityVersion,
    DateTimeOffset OccurredAtUtc,
    string? TraceParent,
    Guid UserId,
    Guid ExamId,
    int Correct,
    int Total);

public interface IExamEventPublisher
{
    Task PublishAsync(ExamSubmittedEvent @event, CancellationToken cancellationToken);
}

public interface ICustomExamStore
{
    Task<bool> CreateAsync(StoredExam exam, TimeSpan ttl, CancellationToken cancellationToken);
    Task<StoredExam?> ReadAsync(Guid examId, CancellationToken cancellationToken);
    Task<bool> CompareExchangeAsync(StoredExam original, StoredExam updated, CancellationToken cancellationToken);
}

public interface IExamDeadlineQueue
{
    Task<IReadOnlyList<Guid>> GetDueAsync(DateTimeOffset nowUtc, int limit,
        CancellationToken cancellationToken);
    Task PostponeAsync(Guid examId, DateTimeOffset nextAttemptUtc, CancellationToken cancellationToken);
    Task RemoveAsync(Guid examId, CancellationToken cancellationToken);
}

public sealed record StoredQuestion(
    string Id, string Version, string Text, IReadOnlyList<ExamOption> Options, string CorrectOptionId, bool IsCritical = false, IReadOnlyList<ExamAsset>? Assets = null,
    string? Explanation = null, string? ExplanationAnimationUrl = null);

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
    IReadOnlyDictionary<string, string> Answers, Guid BankId = default, int PassingScore = 0, bool FailOnCriticalWrong = false,
    string? TemplateCode = null, int? TemplateVersion = null);
