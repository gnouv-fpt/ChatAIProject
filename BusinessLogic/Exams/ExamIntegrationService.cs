using System.Security.Cryptography;
using System.Text.Json;
using BusinessLogic.Exceptions;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Configuration;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Infrastructure.Settings;

namespace BusinessLogic.Exams;

public sealed class ExamIntegrationService(IContentBankRepository banks, IQuestionCatalogRepository catalog)
{
    public async Task<TemplateQuestionSet> GetTemplateAsync(string code, int version, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(code) || version < 1)
            throw new BadRequestException("Mã hoặc phiên bản đề mẫu không hợp lệ.");
        var template = await catalog.GetPublishedTemplateAsync(code, version, ct)
            ?? throw new NotFoundException("Không tìm thấy đề mẫu đã xuất bản.");
        var rows = template.Items.OrderBy(i => i.OrderIndex).Select(i => i.Question).ToArray();
        if (rows.Length == 0 || rows.Select(q => (q.BankCode, q.BankVersion)).Distinct().Count() != 1 ||
            !Guid.TryParseExact(rows[0].BankCode, "N", out var bankId))
            throw new ConflictException("Đề mẫu tham chiếu bank không hợp lệ.");
        var bankVersion = rows[0].BankVersion.ToString(System.Globalization.CultureInfo.InvariantCulture);
        var package = await banks.GetAsync(bankId, bankVersion, ct);
        if (package is null || !package.IsPublished)
            throw new ConflictException("Bank của đề mẫu chưa được xuất bản.");
        OfficialExamRules.ValidateTemplate(package.Bank, rows.Select(q => q.Id).ToArray(), template.DurationMinutes, template.PassingScore);
        var byId = package.Bank.Questions.ToDictionary(q => q.Id);
        if (rows.Any(q => !byId.ContainsKey(q.Id)))
            throw new ConflictException("Câu hỏi đề mẫu không khớp bank đã xuất bản.");
        var questions = rows.Select(row => {
            var q = byId[row.Id];
            return new BankQuestion(row.Id.ToString(), bankVersion, q.Text,
                q.Options.Select(o => new ExamOption(o.Id, o.Text)).ToArray(), row.CorrectAnswerKey,
                row.AllowOptionShuffle, bankId, row.IsParalysisQuestion, template.PassingScore,
                package.Bank.Profile.FailOnCriticalWrong,
                q.Assets.Select(a => new ExamAsset(a.Id, a.Url, a.AltText, a.Sha256, a.MimeType)).ToArray(),
                q.Explanation, row.ExplanationAnimationUrl);
        }).ToArray();
        return new TemplateQuestionSet(bankVersion, template.DurationMinutes, template.PassingScore, questions);
    }

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
        if (OfficialExamRules.IsOfficial(package.Bank.Profile))
        {
            OfficialExamRules.ValidateProfile(package.Bank.Profile);
            throw new BadRequestException("Hãy chọn đề thi thử hạng B trong Luyện thi để giữ đúng cấu trúc và thời gian sát hạch. Tự chọn số câu dùng bank luyện tập.");
        }
        Guid? category = parts.Length == 2 ? Guid.Parse(parts[1]) : null;
        var rows = await catalog.GetPublishedAsync(bankId.ToString("N"), revision, category, ct);
        // Custom practice keeps the profile's target ratio when the learner changes N.
        var passingScore = (int)Math.Ceiling((decimal)package.Bank.Profile.PassCount * count / package.Bank.Profile.QuestionCount);
        return rows.Select(row =>
        {
            var question = package.Bank.Questions.Single(q => q.Id == row.Id);
            return new BankQuestion(row.Id.ToString(), bankVersion, question.Text,
                question.Options.Select(o => new ExamOption(o.Id, o.Text)).ToList(), row.CorrectAnswerKey,
                row.AllowOptionShuffle, bankId, row.IsParalysisQuestion,
                passingScore, package.Bank.Profile.FailOnCriticalWrong,
                question.Assets.Select(a => new ExamAsset(a.Id, a.Url, a.AltText, a.Sha256, a.MimeType)).ToList(),
                question.Explanation, row.ExplanationAnimationUrl);
        }).ToList();
    }
}

public sealed class ExamResultService(IExamAttemptRepository attempts, IUserRepository users,
    IConfiguration configuration, AnimationSettings? animationSettings = null) : IExamResultSink
{
    public async Task<ExamAttemptReview> GetReviewAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var attempt = await GetOwnedAsync(userId, id, ct);
        var snapshot = JsonSerializer.Deserialize<SaveExamResult>(attempt.ExamSnapshotJson)
            ?? throw new ConflictException("Không đọc được nội dung lượt thi đã lưu.");
        var hosts = configuration.GetSection("Content:AnimationAllowedHosts").GetChildren()
            .Select(item => item.Value).OfType<string>().ToArray();
        // Read only the submitted snapshot: later bank edits and Redis expiry cannot change a review.
        var questions = snapshot.Questions.Select(q => q with
        {
            ExplanationAnimationUrl = ContentManifestService.IsAllowedAnimationUrl(q.ExplanationAnimationUrl, hosts, animationSettings?.LocalAssetOrigin)
                ? q.ExplanationAnimationUrl : null
        }).ToArray();
        return new(attempt.Id, snapshot.ExamId, snapshot.BankId, snapshot.BankVersion,
            attempt.Score, questions.Length, attempt.IsPassed, snapshot.SubmittedAtUtc, questions, hosts, animationSettings?.LocalAssetOrigin);
    }

    public async Task<IReadOnlyList<ExamSubmittedEvent>> GetRecentNotificationsAsync(Guid userId, CancellationToken ct)
    {
        var history = await attempts.GetHistoryAsync(userId, 1, 50, ct);
        return history.Where(attempt => Guid.TryParseExact(attempt.ExamCode, "N", out _))
            .Select(attempt => new ExamSubmittedEvent(
            attempt.Id, 1, attempt.Id, 1,
            new DateTimeOffset(DateTime.SpecifyKind(attempt.SubmittedAt, DateTimeKind.Utc)),
            null, attempt.UserId, Guid.ParseExact(attempt.ExamCode, "N"),
            attempt.Score, ReadQuestionCount(attempt.ExamSnapshotJson))).ToArray();
    }

    private static int ReadQuestionCount(string snapshot)
    {
        using var document = JsonDocument.Parse(snapshot);
        return document.RootElement.TryGetProperty("Questions", out var questions) &&
            questions.ValueKind == JsonValueKind.Array ? questions.GetArrayLength() : 0;
    }

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
