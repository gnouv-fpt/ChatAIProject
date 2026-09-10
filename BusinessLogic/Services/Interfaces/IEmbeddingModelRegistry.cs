using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

public interface IEmbeddingModelRegistry
{
    IEmbeddingService GetDefault();

    Task<IEmbeddingService> GetConfiguredDefaultAsync(CancellationToken cancellationToken = default);

    IEmbeddingService GetRequired(string modelKey);

    IReadOnlyList<EmbeddingModelDto> GetAvailableModels(bool benchmarkOnly = false);
}
