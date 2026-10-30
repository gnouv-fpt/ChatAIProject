using System.Security.Cryptography;
using System.Text.Json;
using BusinessLogic.Exceptions;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Exams;

public sealed class ExamIntegrationService(IContentBankRepository banks, IQuestionCatalogRepository catalog)
{
    public async Task<IReadOnlyList<BankQuestion>> GetPoolAsync(string categoryId, string bankVersion, int count, CancellationToken ct)
    {
        if (!int.TryParse(bankVersion, out var revision) || revision < 1 || count is < 1 or > 100)
            throw new BadRequestException("Version hoặc số câu không hợp lệ.");
        // categoryId is an unambiguous bank GUID, optionally followed by a category GUID.
        var parts = categoryId.Split(':');
        if (parts.Length > 2 || !Guid.TryParse(parts[0], out var bankId) ||
            (parts.Length == 2 && !Guid.TryParse(parts[1], out _)))
            throw new BadRequestException("Chọn mã ngân hàng, hoặc bankId:categoryId.");
        var package = await banks.GetAsync(bankId, bankVersion, ct);
        if (package is null || !package.IsPublished) throw new NotFoundException("Không tìm thấy ngân hàng đã xuất bản.");
        Guid? category = parts.Length == 2 ? Guid.Parse(parts[1]) : null;
        var rows = await catalog.GetPublishedAsync(bankId.ToString("N"), revision, category, ct);
        return rows.Select(row =>
        {
            var question = package.Bank.Questions.Single(q => q.Id == row.Id);
            return new BankQuestion(row.Id.ToString(), bankVersion, question.Text,
                question.Options.Select(o => new ExamOption(o.Id, o.Text)).ToList(), row.CorrectAnswerKey,
                row.AllowOptionShuffle, bankId, row.IsParalysisQuestion,
                package.Bank.Profile.PassCount, package.Bank.Profile.FailOnCriticalWrong,
                question.Assets.Select(a => new ExamAsset(a.Id, a.Url, a.AltText, a.Sha256, a.MimeType)).ToList(),
                question.Explanation, row.ExplanationAnimationUrl);
        }).ToList();
    }
}

public sealed class ExamResultService(IExamAttemptRepository attempts, IUserRepository users) : IExamResultSink
{
    public async Task SaveAsync(SaveExamResult result, CancellationToken ct)
    {
        if (result.AttemptId == Guid.Empty || result.ExamId == Guid.Empty || result.UserId == Guid.Empty ||
            result.BankId == Guid.Empty || !int.TryParse(result.BankVersion, out var version) || version < 1 ||
            result.Questions is not { Count: > 0 and <= 100 } || result.Total != result.Questions.Count ||
            result.Questions.Select(q => q.QuestionId).Distinct().Count() != result.Total ||
            result.Questions.Any(q => !Guid.TryParse(q.QuestionId, out _) || q.Version != result.BankVersion ||
                q.Options is not { Count: >= 2 and <= 10 } || q.Options.Select(o => o.Id).Distinct().Count() != q.Options.Count ||
                !q.Options.Any(o => o.Id == q.CorrectOptionId) ||
                q.SelectedOptionId is not null && !q.Options.Any(o => o.Id == q.SelectedOptionId)) ||
            result.Correct != result.Questions.Count(q => q.SelectedOptionId == q.CorrectOptionId) ||
            result.PassingScore < 0 || result.StartedAtUtc is null || result.DeadlineUtc is null ||
            result.StartedAtUtc > result.SubmittedAtUtc || result.DeadlineUtc <= result.StartedAtUtc ||
            result.SubmittedAtUtc > DateTimeOffset.UtcNow.AddMinutes(1))
            throw new BadRequestException("Kết quả hoặc snapshot lượt thi không hợp lệ.");
        if (await users.GetByIdAsync(result.UserId, ct) is null) throw new NotFoundException("Không tìm thấy người dùng.");
        var json = JsonSerializer.Serialize(result);
        var hash = Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(json)));
        var attempt = new ExamAttempt
        {
            Id = result.AttemptId, UserId = result.UserId, ExamCode = result.ExamId.ToString("N"), ExamVersion = version,
            Score = result.Correct,
            IsPassed = result.Correct >= result.PassingScore && !(result.FailOnCriticalWrong &&
                result.Questions.Any(q => q.IsCritical && q.SelectedOptionId != q.CorrectOptionId)),
            TimeSpentSeconds = (int)Math.Max(0, (result.SubmittedAtUtc - result.StartedAtUtc.Value).TotalSeconds),
            ExamSnapshotJson = json, UserAnswersJson = JsonSerializer.Serialize(result.Questions.Select(q => new { q.QuestionId, q.SelectedOptionId })),
            SubmittedAt = result.SubmittedAtUtc.UtcDateTime, SubmissionHash = hash
        };
        var saved = await attempts.InsertOrGetAsync(attempt, ct);
        if (saved.UserId != result.UserId || saved.SubmissionHash != hash)
            throw new ConflictException("Mã lượt thi đã được lưu với nội dung khác.");
    }

    public async Task<ExamAttempt> GetOwnedAsync(Guid userId, Guid id, CancellationToken ct) =>
        await attempts.GetOwnedAsync(id, userId, ct) ?? throw new NotFoundException("Không tìm thấy lượt thi.");
}
