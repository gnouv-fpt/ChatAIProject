using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

public interface ITokenUsageService
{
    Task<TokenUsageSummaryDto> GetUserUsageAsync(int userId, CancellationToken cancellationToken = default);

    Task<AdminTokenUsageDto> GetAdminUsageAsync(CancellationToken cancellationToken = default);

    Task<EmbeddingTokenUsageChartDto> GetEmbeddingModelUsageAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyList<DailyEmbeddingModelTokenUsageDto>> GetDailyEmbeddingModelUsageThisMonthAsync(
        CancellationToken cancellationToken = default);
}
