using BusinessObject.Enums;

namespace BusinessLogic.DTOs.Responses;

public sealed record BankProgressDto(
    Guid BankId,
    string BankCode,
    string BankName,
    int BankVersion,
    string? LicenseClass,
    QuestionBankStatus BankStatus,
    int TotalQuestions,
    int AnsweredQuestions,
    int CorrectQuestions,
    int WrongQuestions,
    int UnseenQuestions,
    int BookmarkedQuestions,
    int GradedAnswers,
    int CorrectAnswers,
    double AccuracyPercent,
    int PracticeAttempts,
    int CompletedExams,
    int PassedExams,
    int? BestExamScore,
    DateTime? LastActivityAt,
    IReadOnlyList<TopicProgressDto> Topics);

public sealed record TopicProgressDto(
    string Topic,
    int TotalQuestions,
    int AnsweredQuestions,
    int CorrectQuestions,
    int WrongQuestions);

public sealed record QuestionProgressItemDto(
    Guid QuestionId,
    int Number,
    string Topic,
    bool IsCritical,
    bool HasImage,
    string ContentPreview,
    int WrongAnswers,
    DateTime? LastAnsweredAt);

public sealed record AttemptHistoryItemDto(
    Guid AttemptId,
    Guid BankId,
    string BankName,
    int BankVersion,
    Guid? ExamTemplateId,
    string? ExamTemplateName,
    AttemptMode Mode,
    AttemptStatus Status,
    int QuestionCount,
    int AnsweredCount,
    int? CorrectCount,
    int? Score,
    bool? IsPassed,
    DateTime StartedAt,
    DateTime? DeadlineAt,
    DateTime? SubmittedAt);

public sealed record BookmarkItemDto(
    Guid QuestionId,
    Guid BankId,
    string BankName,
    int BankVersion,
    int Number,
    string Topic,
    string ContentPreview,
    bool HasImage,
    DateTime BookmarkedAt);
