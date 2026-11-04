using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;

namespace BusinessLogic.Services.Implementations;

// Apply the exact reviewed animation mapping on the server before SQL import/hash calculation.
public sealed class ContentBankImportService(IContentManifestService manifests, IQuestionBankService banks)
{
    public async Task<BankPreviewDto> ImportAsync(ImportQuestionBankRequestDto request, Guid adminId,
        CancellationToken cancellationToken = default)
    {
        var preview = manifests.Preview(new() { Bank = request.Bank, Animations = request.Animations });
        if (!preview.CanImport)
            throw new BadRequestException(string.Join(" ", preview.Issues.Take(30).Select(i => $"{i.Path}: {i.Message}")));
        if (request.ExpectedManifestHash is not null &&
            !string.Equals(request.ExpectedManifestHash, preview.ManifestHash, StringComparison.OrdinalIgnoreCase))
            throw new ConflictException("Gói nội dung đã thay đổi so với bản kiểm tra. Hãy kiểm tra lại trước khi nhập.");
        var mappings = request.Animations.ToDictionary(a => a.QuestionId, a => a.ExplanationAnimationUrl);
        var bank = request.Bank with {
            Questions = request.Bank.Questions.Select(q => mappings.TryGetValue(q.Id, out var url)
                ? q with { ExplanationAnimationUrl = url } : q).ToList()
        };
        return await banks.ImportAsync(bank, adminId, cancellationToken);
    }
}
