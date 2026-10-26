using BusinessLogic.DTOs;
using BusinessObject.Entities;

namespace BusinessLogic.Services.Interfaces;

public interface IQuestionBankService
{
    Task<BankPreviewDto> ImportAsync(QuestionBank bank, Guid adminId, CancellationToken cancellationToken = default);
    Task<BankPreviewDto> PreviewAsync(Guid id, string version, CancellationToken cancellationToken = default);
    Task<BankSummaryDto> PublishAsync(Guid id, string version, PublishBankRequestDto request, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<BankSummaryDto>> ListAsync(bool includeDrafts, CancellationToken cancellationToken = default);
    Task<PagedResult<QuestionDto>> GetQuestionsAsync(Guid id, string version, string? topic, int? from, int? to,
        int page, int pageSize, CancellationToken cancellationToken = default);
}
