using System.ComponentModel.DataAnnotations;
using BusinessObject.Entities;

namespace BusinessLogic.DTOs;

public sealed class ImportQuestionBankRequestDto
{
    [Required(ErrorMessage = "Thiếu gói ngân hàng câu hỏi.")]
    public QuestionBank Bank { get; set; } = null!;
}

public sealed class PublishBankRequestDto
{
    [Required, RegularExpression("^[A-Fa-f0-9]{64}$", ErrorMessage = "Hash SHA-256 không hợp lệ.")]
    public string ExpectedHash { get; set; } = "";
    [Range(typeof(bool), "true", "true", ErrorMessage = "Cần xác nhận đã kiểm tra nguồn và đáp án.")]
    public bool SourceAndAnswersReviewed { get; set; }
}

public sealed record BankSummaryDto(Guid Id, string Version, string Title, string SourceUrl,
    string SourceDescription, int QuestionCount, string Hash, bool IsPublished, ExamProfile Profile);
public sealed record QuestionDto(Guid Id, int Number, string Topic, string Text, bool IsCritical,
    bool AllowOptionShuffle, IReadOnlyList<QuestionOption> Options, IReadOnlyList<QuestionAsset> Assets, string SourceUrl);
public sealed record BankPreviewDto(BankSummaryDto Summary, QuestionBank Bank, IReadOnlyList<string> Errors);
