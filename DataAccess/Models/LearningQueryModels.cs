using BusinessObject.Enums;

namespace DataAccess.Models;

public sealed record QuestionQuery(
    Guid BankId,
    string? Topic = null,
    string? Search = null,
    int? FromNumber = null,
    int? ToNumber = null,
    bool? HasImage = null,
    bool? IsCritical = null,
    int PageIndex = 1,
    int PageSize = 20);

public sealed record TopicCountRow(string Topic, int QuestionCount);

public sealed record QuestionSummaryRow(Guid Id, Guid BankId, int Number, string Topic, bool IsCritical, bool HasImage, string Content);

// One graded or ungraded answer slot of the user, with the attempt state needed to decide whether it counts.
public sealed record AnswerHistoryRow(
    Guid AttemptId,
    AttemptMode Mode,
    AttemptStatus AttemptStatus,
    Guid QuestionId,
    bool? IsCorrect,
    DateTime? AnsweredAt,
    DateTime? SubmittedAt);

public sealed record AttemptSummaryRow(
    Guid Id,
    AttemptMode Mode,
    AttemptStatus Status,
    int? Score,
    bool? IsPassed,
    DateTime StartedAt,
    DateTime? SubmittedAt);

public sealed record AttemptHistoryRow(
    Guid Id,
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

public sealed record BookmarkRow(
    Guid QuestionId,
    Guid BankId,
    string BankName,
    int BankVersion,
    int Number,
    string Topic,
    string Content,
    bool HasImage,
    DateTime BookmarkedAt);
