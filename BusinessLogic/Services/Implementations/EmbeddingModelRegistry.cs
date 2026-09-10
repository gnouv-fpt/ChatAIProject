using BusinessLogic.Services.Interfaces;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Infrastructure.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class EmbeddingModelRegistry : IEmbeddingModelRegistry
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<ConfiguredEmbeddingService> _embeddingLogger;
    private readonly ISystemSettingsService _systemSettingsService;
    private readonly EmbeddingSettings _settings;

    public EmbeddingModelRegistry(
        IHttpClientFactory httpClientFactory,
        IConfiguration configuration,
        ISystemSettingsService systemSettingsService,
        ILogger<ConfiguredEmbeddingService> embeddingLogger)
    {
        _httpClientFactory = httpClientFactory;
        _embeddingLogger = embeddingLogger;
        _systemSettingsService = systemSettingsService;
        _settings = EmbeddingSettings.FromConfiguration(configuration);
    }

    public IEmbeddingService GetDefault()
    {
        return GetRequired(_settings.DefaultModelKey);
    }

    public async Task<IEmbeddingService> GetConfiguredDefaultAsync(CancellationToken cancellationToken = default)
    {
        var settings = await _systemSettingsService.GetSettingsAsync(cancellationToken);
        if (!string.IsNullOrWhiteSpace(settings.EmbeddingModel) && HasEnabledModel(settings.EmbeddingModel))
        {
            return GetRequired(settings.EmbeddingModel);
        }

        return GetDefault();
    }

    public IEmbeddingService GetRequired(string modelKey)
    {
        var model = _settings.Models.FirstOrDefault(item =>
            item.Enabled && string.Equals(item.Key, modelKey, StringComparison.OrdinalIgnoreCase));

        if (model is null)
        {
            throw new InvalidOperationException($"Embedding model '{modelKey}' was not found.");
        }

        return new ConfiguredEmbeddingService(
            _httpClientFactory.CreateClient($"Embedding:{model.Key}"),
            model,
            _embeddingLogger);
    }

    private bool HasEnabledModel(string modelKey)
    {
        return _settings.Models.Any(item =>
            item.Enabled
            && !string.Equals(item.Provider, "Fake", StringComparison.OrdinalIgnoreCase)
            && string.Equals(item.Key, modelKey, StringComparison.OrdinalIgnoreCase));
    }

    public IReadOnlyList<EmbeddingModelDto> GetAvailableModels(bool benchmarkOnly = false)
    {
        return _settings.Models
            .Where(model => model.Enabled && (!benchmarkOnly || model.IncludeInBenchmark))
            .Select(model => new EmbeddingModelDto(
                model.Key,
                model.Provider,
                model.Model,
                model.Dimension,
                model.Enabled,
                model.IncludeInBenchmark))
            .ToList();
    }
}
