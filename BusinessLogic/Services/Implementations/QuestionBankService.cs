using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class QuestionBankService(IContentBankRepository repository, BusinessLogic.Infrastructure.Settings.AnimationSettings? animationSettings = null) : IQuestionBankService
{
    private static readonly Guid ScenarioBankId = Guid.Parse("cfa49411-a01c-50d6-88a2-7e25b1e888f7");
    private const string ScenarioBankHash = "F5DC146565D8D2DB072F245E94278D36909FFAE668383802D7EEE7B18414C65B";

    public async Task<ScenarioAnswerDto?> ResolveScenarioAsync(int? number, IReadOnlyList<string> imageHashes,
        CancellationToken cancellationToken = default)
    {
        if (number is < 486 or > 600 || imageHashes.Count > 4 ||
            imageHashes.Any(hash => !Regex.IsMatch(hash, "^[a-fA-F0-9]{64}$"))) return null;
        var package = await repository.GetAsync(ScenarioBankId, "1", cancellationToken);
        if (package is null || !package.IsPublished ||
            !string.Equals(package.Hash, ScenarioBankHash, StringComparison.OrdinalIgnoreCase) ||
            Hash(package.Bank) != package.Hash || package.Bank.Questions.Count != 600) return null;
        var candidates = package.Bank.Questions.Where(q => q.Number is >= 486 and <= 600 &&
            q.CategoryType == "SCENARIO" && (number.HasValue ? q.Number == number.Value :
                imageHashes.Any(hash => q.Assets.Any(asset =>
                    string.Equals(asset.Sha256, hash, StringComparison.OrdinalIgnoreCase))))).ToList();
        if (candidates.Count != 1) return null;
        var question = candidates[0];
        if (number.HasValue && question.Number != number.Value || imageHashes.Count > 0 &&
            !imageHashes.Any(hash => question.Assets.Any(asset =>
                string.Equals(asset.Sha256, hash, StringComparison.OrdinalIgnoreCase)))) return null;
        if (question.CorrectOptionIds.Count == 0 || question.CorrectOptionIds.Any(id =>
            !question.Options.Any(option => option.Id == id)) || !Https(question.SourceUrl)) return null;
        return new ScenarioAnswerDto(question.Number, question.Text, question.Options,
            question.CorrectOptionIds, question.Explanation, question.SourceUrl,
            question.Assets.FirstOrDefault()?.Url);
    }
    public static IReadOnlyList<string> Validate(ContentBank bank, string? localAssetOrigin = null)
    {
        var errors = new List<string>();
        void Require(bool condition, string message) { if (!condition) errors.Add(message); }
        Require(bank.Id != Guid.Empty, "Thiếu ID ngân hàng.");
        Require(int.TryParse(bank.Version, out var revision) && revision > 0 && revision.ToString() == bank.Version,
            "C2 cần version nội bộ là số nguyên dương; giữ version nguồn trong mô tả nguồn.");
        Require(!string.IsNullOrWhiteSpace(bank.Title) && bank.Title.Length <= 500, "Tên ngân hàng không hợp lệ.");
        Require(Https(bank.SourceUrl) && !string.IsNullOrWhiteSpace(bank.SourceDescription), "Cần URL HTTPS và mô tả nguồn; không tự khẳng định nguồn chính thức.");
        var profile = bank.Profile;
        Require(profile is not null, "Thiếu profile.");
        if (profile is not null)
        {
            try { BusinessLogic.Exams.OfficialExamRules.ValidateProfile(profile); }
            catch (AppException ex) { errors.Add(ex.Message); }
            Require(!string.IsNullOrWhiteSpace(profile.Id) && ValidVersion(profile.Version) && Https(profile.SourceUrl), "Profile cần ID, version và URL nguồn.");
            Require(profile.QuestionCount > 0 && profile.DurationSeconds > 0 && profile.DurationSeconds <= 86400 &&
                profile.PassCount > 0 && profile.PassCount <= profile.QuestionCount, "Số câu, thời gian hoặc điểm đạt của profile không hợp lệ.");
        }
        var questions = bank.Questions;
        Require(questions is { Count: > 0 and <= 5000 }, "Ngân hàng cần từ 1 đến 5000 câu.");
        if (questions is null) return errors;
        Require(questions.All(q => q is not null), "Câu hỏi không được null.");
        if (questions.Any(q => q is null)) return errors;
        Require(questions.Select(q => q.Id).Distinct().Count() == questions.Count && questions.All(q => q.Id != Guid.Empty), "ID câu hỏi thiếu hoặc trùng.");
        Require(questions.Select(q => q.Number).Distinct().Count() == questions.Count && questions.All(q => q.Number > 0), "Số thứ tự câu thiếu hoặc trùng.");
        Require(profile is null || profile.QuestionCount <= questions.Count, "Pool không đủ số câu theo profile.");
        foreach (var q in questions)
        {
            var prefix = $"Câu {q.Number}: ";
            Require(!string.IsNullOrWhiteSpace(q.Text) && q.Text.Length <= 20000 &&
                !string.IsNullOrWhiteSpace(q.Topic) && q.Topic.Length <= 255 && !string.IsNullOrWhiteSpace(q.Explanation) && Https(q.SourceUrl), prefix + "thiếu nội dung/chủ đề/giải thích/nguồn.");
            Require(q.CategoryType is "RULES" or "CULTURE" or "DRIVING" or "MECHANICS" or "SIGN" or "SCENARIO",
                prefix + "CategoryType phải thuộc một trong sáu nhóm nội dung nguồn đã hỗ trợ.");
            Require(q.Options is { Count: >= 2 and <= 10 } && q.Options.All(o => o is not null &&
                !string.IsNullOrWhiteSpace(o.Id) && o.Id.Length <= 30 && !string.IsNullOrWhiteSpace(o.Text)) &&
                q.Options.Select(o => o.Id).Distinct(StringComparer.Ordinal).Count() == q.Options.Count, prefix + "phương án thiếu hoặc trùng ID.");
            Require(q.CorrectOptionIds is { Count: 1 } && q.CorrectOptionIds.Distinct().Count() == q.CorrectOptionIds.Count &&
                q.CorrectOptionIds.All(key => q.Options?.Any(o => o is not null && o.Id == key) == true), prefix + "đáp án không thuộc phương án hoặc bị trùng.");
            Require(q.Assets is not null && q.Assets.All(a => a is not null && !string.IsNullOrWhiteSpace(a.Id) &&
                (Https(a.Url) || BusinessLogic.Infrastructure.Settings.AnimationSettings.IsLocalAssetUrl(a.Url, localAssetOrigin)) && Regex.IsMatch(a.Sha256 ?? "", "^[A-Fa-f0-9]{64}$") &&
                a.MimeType is "image/png" or "image/jpeg" or "image/webp" && !string.IsNullOrWhiteSpace(a.AltText)) &&
                q.Assets.Select(a => a.Id).Distinct().Count() == q.Assets.Count, prefix + "metadata ảnh không hợp lệ.");
            var labelReferences = q.Options?.Any(o => o is not null && Regex.IsMatch(o.Text ?? "",
                @"(?i)(tất cả|cả .+ và|phương án\s+[A-D1-4]|đáp án\s+[A-D1-4]|all of|both .+ and)")) == true;
            Require(!q.AllowOptionShuffle || (q.Assets?.Count == 0 && !labelReferences), prefix + "có tham chiếu nhãn/ảnh, cần tắt trộn phương án.");
        }
        return errors;
    }

    public async Task<BankPreviewDto> ImportAsync(ContentBank bank, Guid adminId, CancellationToken cancellationToken = default)
    {
        var errors = Validate(bank, animationSettings?.LocalAssetOrigin);
        if (errors.Count > 0) throw new BadRequestException(string.Join(" ", errors.Take(30)));
        var questions = bank.Questions ?? throw new BadRequestException("Thiếu danh sách câu hỏi.");
        if (questions.Any(q => q.ExplanationAnimationUrl is not null &&
            !ContentManifestService.IsAllowedAnimationUrl(q.ExplanationAnimationUrl, animationSettings?.AllowedHosts ?? [], animationSettings?.LocalAssetOrigin)))
            throw new BadRequestException("Animation cần URL HTTPS trên host được cấu hình.");
        var hash = Hash(bank);
        var package = new QuestionBankPackage(bank, hash, DateTime.UtcNow, adminId);
        if (!await repository.AddAsync(package, cancellationToken))
        {
            var existing = await repository.GetAsync(bank.Id, bank.Version, cancellationToken);
            if (existing?.Hash != hash) throw new ConflictException("Version hoặc ID câu hỏi đã tồn tại với nội dung khác. Hãy tạo version và ID câu hỏi mới.");
            package = existing;
        }
        return new(Summary(package), package.Bank, errors);
    }

    public async Task<BankPreviewDto> PreviewAsync(Guid id, string version, CancellationToken cancellationToken = default)
    {
        var package = await GetAsync(id, version, cancellationToken);
        return new(Summary(package), package.Bank, Validate(package.Bank, animationSettings?.LocalAssetOrigin));
    }

    public async Task<BankSummaryDto> PublishAsync(Guid id, string version, PublishBankRequestDto request, CancellationToken cancellationToken = default)
    {
        var package = await GetAsync(id, version, cancellationToken);
        if (!request.SourceAndAnswersReviewed) throw new BadRequestException("Cần kiểm tra nguồn, ảnh và đáp án trước khi xuất bản.");
        var errors = Validate(package.Bank, animationSettings?.LocalAssetOrigin);
        if (errors.Count > 0) throw new BadRequestException(string.Join(" ", errors.Take(30)));
        if (!string.Equals(package.Hash, request.ExpectedHash, StringComparison.OrdinalIgnoreCase) || Hash(package.Bank) != package.Hash)
            throw new ConflictException("Nội dung đã thay đổi hoặc hash không khớp bản xem trước.");
        if (!await repository.PublishAsync(id, version, package.Hash, cancellationToken))
            throw new ConflictException("Không thể xuất bản version này.");
        return Summary((await repository.GetAsync(id, version, cancellationToken))!);
    }

    public async Task<IReadOnlyList<BankSummaryDto>> ListAsync(bool includeDrafts, CancellationToken cancellationToken = default) =>
        (await repository.ListAsync(cancellationToken)).Where(p => includeDrafts || p.IsPublished)
        .OrderBy(p => p.Bank.Title).ThenBy(p => p.Bank.Version).Select(Summary).ToList();

    public async Task<PagedResult<QuestionDto>> GetQuestionsAsync(Guid id, string version, string? topic, int? from, int? to,
        int page, int pageSize, CancellationToken cancellationToken = default)
    {
        var package = await GetAsync(id, version, cancellationToken);
        if (!package.IsPublished) throw new NotFoundException("Không tìm thấy ngân hàng đã xuất bản.");
        if (page < 1 || pageSize is < 1 or > 100 || from is <= 0 || to is <= 0 || from > to)
            throw new BadRequestException("Phân trang hoặc khoảng câu không hợp lệ.");
        var questions = package.Bank.Questions.Where(q => (topic is null || q.Topic == topic) &&
            (!from.HasValue || q.Number >= from) && (!to.HasValue || q.Number <= to)).OrderBy(q => q.Number).ToList();
        return new() { TotalCount = questions.Count, PageIndex = page, PageSize = pageSize,
            Items = questions.Skip((int)Math.Min((long)(page - 1) * pageSize, int.MaxValue)).Take(pageSize)
            .Select(q => new QuestionDto(q.Id, q.Number, q.Topic, q.Text, q.IsCritical, q.AllowOptionShuffle, q.Options, q.Assets, q.SourceUrl)).ToList() };
    }

    public async Task<LearningAnswerDto> GetLearningAnswerAsync(Guid bankId, string version, Guid questionId,
        CancellationToken cancellationToken = default)
    {
        var package = await GetAsync(bankId, version, cancellationToken);
        if (!package.IsPublished) throw new NotFoundException("Không tìm thấy ngân hàng đã xuất bản.");
        var question = package.Bank.Questions.FirstOrDefault(q => q.Id == questionId)
            ?? throw new NotFoundException("Không tìm thấy câu hỏi.");
        var explanation = Regex.Replace(question.Explanation,
            @"\r?\nTheo phương án gạch chân trong PDF Cục CSGT 2025, trang PDF \d+\. Không bổ sung diễn giải hay căn cứ điều luật ngoài tài liệu nguồn\.",
            string.Empty);
        return new LearningAnswerDto(question.CorrectOptionIds, explanation);
    }

    private async Task<QuestionBankPackage> GetAsync(Guid id, string version, CancellationToken cancellationToken)
    {
        if (!ValidVersion(version)) throw new BadRequestException("Version không hợp lệ.");
        return await repository.GetAsync(id, version, cancellationToken) ?? throw new NotFoundException("Không tìm thấy ngân hàng/version.");
    }
    private static bool ValidVersion(string? version) => version is not null && Regex.IsMatch(version, "^[A-Za-z0-9._-]{1,64}$");
    private static bool Https(string? value) => Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.Scheme == "https" && string.IsNullOrEmpty(uri.UserInfo);
    private static string Hash(ContentBank bank) => Convert.ToHexString(SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(bank)));
    private static BankSummaryDto Summary(QuestionBankPackage p) => new(p.Bank.Id, p.Bank.Version, p.Bank.Title,
        p.Bank.SourceUrl, p.Bank.SourceDescription, p.Bank.Questions.Count, p.Hash, p.IsPublished, p.Bank.Profile,
        p.Bank.Questions.GroupBy(q => q.CategoryType).ToDictionary(g => g.Key, g => g.Count()));
}
