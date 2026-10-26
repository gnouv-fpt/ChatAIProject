using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class QuestionBankService(IQuestionBankRepository repository) : IQuestionBankService
{
    public static IReadOnlyList<string> Validate(QuestionBank bank)
    {
        var errors = new List<string>();
        void Require(bool condition, string message) { if (!condition) errors.Add(message); }
        Require(bank.Id != Guid.Empty, "Thiếu ID ngân hàng.");
        Require(ValidVersion(bank.Version), "Version chỉ gồm chữ ASCII, số, dấu chấm, gạch ngang/gạch dưới; tối đa 64 ký tự.");
        Require(!string.IsNullOrWhiteSpace(bank.Title) && bank.Title.Length <= 500, "Tên ngân hàng không hợp lệ.");
        Require(Https(bank.SourceUrl) && !string.IsNullOrWhiteSpace(bank.SourceDescription), "Cần URL HTTPS và mô tả nguồn; không tự khẳng định nguồn chính thức.");
        var profile = bank.Profile;
        Require(profile is not null, "Thiếu profile.");
        if (profile is not null)
        {
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
                !string.IsNullOrWhiteSpace(q.Topic) && !string.IsNullOrWhiteSpace(q.Explanation) && Https(q.SourceUrl), prefix + "thiếu nội dung/chủ đề/giải thích/nguồn.");
            Require(q.Options is { Count: >= 2 and <= 10 } && q.Options.All(o => o is not null &&
                !string.IsNullOrWhiteSpace(o.Id) && !string.IsNullOrWhiteSpace(o.Text)) &&
                q.Options.Select(o => o.Id).Distinct(StringComparer.Ordinal).Count() == q.Options.Count, prefix + "phương án thiếu hoặc trùng ID.");
            Require(q.CorrectOptionIds is { Count: > 0 } && q.CorrectOptionIds.Distinct().Count() == q.CorrectOptionIds.Count &&
                q.CorrectOptionIds.All(key => q.Options?.Any(o => o is not null && o.Id == key) == true), prefix + "đáp án không thuộc phương án hoặc bị trùng.");
            Require(q.Assets is not null && q.Assets.All(a => a is not null && !string.IsNullOrWhiteSpace(a.Id) &&
                Https(a.Url) && Regex.IsMatch(a.Sha256 ?? "", "^[A-Fa-f0-9]{64}$") &&
                a.MimeType is "image/png" or "image/jpeg" or "image/webp" && !string.IsNullOrWhiteSpace(a.AltText)) &&
                q.Assets.Select(a => a.Id).Distinct().Count() == q.Assets.Count, prefix + "metadata ảnh không hợp lệ.");
            var labelReferences = q.Options?.Any(o => o is not null && Regex.IsMatch(o.Text ?? "",
                @"(?i)(tất cả|cả .+ và|phương án\s+[A-D1-4]|đáp án\s+[A-D1-4]|all of|both .+ and)")) == true;
            Require(!q.AllowOptionShuffle || (q.Assets?.Count == 0 && !labelReferences), prefix + "có tham chiếu nhãn/ảnh, cần tắt trộn phương án.");
        }
        return errors;
    }

    public async Task<BankPreviewDto> ImportAsync(QuestionBank bank, Guid adminId, CancellationToken cancellationToken = default)
    {
        var errors = Validate(bank);
        if (errors.Count > 0) throw new BadRequestException(string.Join(" ", errors.Take(30)));
        var hash = Hash(bank);
        var package = new QuestionBankPackage(bank, hash, DateTime.UtcNow, adminId);
        if (!await repository.AddAsync(package, cancellationToken))
        {
            var existing = await repository.GetAsync(bank.Id, bank.Version, cancellationToken);
            if (existing?.Hash != hash) throw new ConflictException("Version đã tồn tại với nội dung khác. Hãy tạo version mới.");
            package = existing;
        }
        return new(Summary(package), package.Bank, errors);
    }

    public async Task<BankPreviewDto> PreviewAsync(Guid id, string version, CancellationToken cancellationToken = default)
    {
        var package = await GetAsync(id, version, cancellationToken);
        return new(Summary(package), package.Bank, Validate(package.Bank));
    }

    public async Task<BankSummaryDto> PublishAsync(Guid id, string version, PublishBankRequestDto request, CancellationToken cancellationToken = default)
    {
        var package = await GetAsync(id, version, cancellationToken);
        if (!request.SourceAndAnswersReviewed) throw new BadRequestException("Cần kiểm tra nguồn, ảnh và đáp án trước khi xuất bản.");
        var errors = Validate(package.Bank);
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

    private async Task<QuestionBankPackage> GetAsync(Guid id, string version, CancellationToken cancellationToken)
    {
        if (!ValidVersion(version)) throw new BadRequestException("Version không hợp lệ.");
        return await repository.GetAsync(id, version, cancellationToken) ?? throw new NotFoundException("Không tìm thấy ngân hàng/version.");
    }
    private static bool ValidVersion(string? version) => version is not null && Regex.IsMatch(version, "^[A-Za-z0-9._-]{1,64}$");
    private static bool Https(string? value) => Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.Scheme == "https" && string.IsNullOrEmpty(uri.UserInfo);
    private static string Hash(QuestionBank bank) => Convert.ToHexString(SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(bank)));
    private static BankSummaryDto Summary(QuestionBankPackage p) => new(p.Bank.Id, p.Bank.Version, p.Bank.Title,
        p.Bank.SourceUrl, p.Bank.SourceDescription, p.Bank.Questions.Count, p.Hash, p.IsPublished, p.Bank.Profile);
}
