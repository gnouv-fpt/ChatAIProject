using System.Text.RegularExpressions;
using BusinessLogic.Exceptions;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed record ImportExamTemplateRequest(string ExamCode, int Version, string Title,
    int DurationMinutes, int PassingScore, IReadOnlyList<Guid> QuestionIds);
public sealed record ExamTemplateDto(Guid Id, string ExamCode, int Version, string Title,
    int DurationMinutes, int PassingScore, bool IsPublished, IReadOnlyList<Guid> QuestionIds);

public sealed class ExamTemplateService(IExamTemplateRepository templates, IQuestionCatalogRepository questions, IContentBankRepository? banks = null)
{
    public async Task<ExamTemplateDto> ImportAsync(ImportExamTemplateRequest request, CancellationToken ct)
    {
        if (request.ExamCode is null || !Regex.IsMatch(request.ExamCode, "^[A-Za-z0-9._-]{1,100}$") ||
            request.Version < 1 || string.IsNullOrWhiteSpace(request.Title) || request.Title.Length > 500 ||
            request.DurationMinutes is < 1 or > 180 || request.QuestionIds is not { Count: > 0 and <= 100 } ||
            request.QuestionIds.Any(id => id == Guid.Empty) || request.QuestionIds.Distinct().Count() != request.QuestionIds.Count ||
            request.PassingScore is < 1 || request.PassingScore > request.QuestionIds.Count)
            throw new BadRequestException("Đề mẫu có mã, thời gian, điểm đạt hoặc danh sách câu không hợp lệ.");
        var rows = await questions.GetByIdsAsync(request.QuestionIds, ct);
        if (rows.Count != request.QuestionIds.Count || rows.Any(q => !q.IsPublished) ||
            rows.Select(q => (q.BankCode, q.BankVersion)).Distinct().Count() != 1)
            throw new BadRequestException("Các câu trong đề mẫu phải thuộc cùng một phiên bản bank đã xuất bản.");
        if (banks is not null && Guid.TryParse(rows[0].BankCode, out var bankId))
        {
            var package = await banks.GetAsync(bankId, rows[0].BankVersion.ToString(), ct)
                ?? throw new BadRequestException("Không tìm thấy gói của đề mẫu.");
            BusinessLogic.Exams.OfficialExamRules.ValidateTemplate(package.Bank, request.QuestionIds, request.DurationMinutes, request.PassingScore);
        }
        var template = new ExamTemplate { Id = Guid.NewGuid(), ExamCode = request.ExamCode,
            Version = request.Version, Title = request.Title.Trim(), DurationMinutes = request.DurationMinutes,
            PassingScore = request.PassingScore, CreatedAt = DateTime.UtcNow,
            Items = request.QuestionIds.Select((id, index) => new ExamTemplateItem {
                Id = Guid.NewGuid(), QuestionId = id, OrderIndex = index + 1 }).ToList() };
        if (!await templates.AddAsync(template, ct)) throw new ConflictException("Mã và phiên bản đề mẫu đã tồn tại.");
        return ToDto(template);
    }

    public async Task<ExamTemplateDto> PublishAsync(string code, int version, CancellationToken ct)
    {
        if (!await templates.PublishAsync(code, version, ct))
            throw new ConflictException("Đề mẫu không tồn tại hoặc câu hỏi chưa được xuất bản.");
        return ToDto((await templates.GetAsync(code, version, ct))!);
    }

    public async Task<IReadOnlyList<ExamTemplateDto>> ListAsync(bool includeDrafts, CancellationToken ct) =>
        (await templates.ListAsync(includeDrafts, ct)).Select(ToDto).ToArray();

    private static ExamTemplateDto ToDto(ExamTemplate template) => new(template.Id, template.ExamCode,
        template.Version, template.Title, template.DurationMinutes, template.PassingScore,
        template.IsPublished, template.Items.OrderBy(i => i.OrderIndex).Select(i => i.QuestionId).ToArray());
}
