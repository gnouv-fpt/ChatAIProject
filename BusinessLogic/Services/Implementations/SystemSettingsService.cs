using BusinessLogic.Services.Interfaces;
using System.Text.Json;
using BusinessLogic.DTOs.Requests;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace BusinessLogic.Services.Implementations;

public sealed class SystemSettingsService : ISystemSettingsService
{
    private readonly string _filePath;
    private readonly IConfiguration _configuration;
    private readonly ILogger<SystemSettingsService> _logger;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public SystemSettingsService(
        IOptions<SystemSettingsFilePathOptions> options,
        IConfiguration configuration,
        ILogger<SystemSettingsService> logger)
    {
        _filePath = options.Value.FilePath;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<SystemSettingsDto> GetSettingsAsync(
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(_filePath))
        {
            return CreateDefaultSettings();
        }

        try
        {
            var json = await File.ReadAllTextAsync(_filePath, cancellationToken);
            return NormalizeSettings(
                JsonSerializer.Deserialize<SystemSettingsDto>(json, JsonOptions)
                ?? new SystemSettingsDto());
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "Failed to read settings from {FilePath}", _filePath);
            return CreateDefaultSettings();
        }
    }

    public async Task SaveSettingsAsync(
        SystemSettingsDto settings,
        CancellationToken cancellationToken = default)
    {
        settings = NormalizeSettings(settings);
        var directory = Path.GetDirectoryName(_filePath);
        if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var json = JsonSerializer.Serialize(settings, JsonOptions);
        await File.WriteAllTextAsync(_filePath, json, cancellationToken);

        _logger.LogInformation("System settings saved to {FilePath}", _filePath);
    }



    private SystemSettingsDto CreateDefaultSettings()
    {
        var settings = new SystemSettingsDto
        {
            EmbeddingProvider = ReadString("Embedding:Provider", "Ollama"),
            EmbeddingModel = ReadString("Embedding:DefaultModelKey", ReadString("Embedding:DefaultModel", "bge-m3")),
            TopK = ReadInt("RagSettings:TopK", 5),
            SimilarityThreshold = ReadDecimal("RagSettings:SimilarityThreshold", 0.7m),
            MaxCitationSnippetLength = ReadInt("RagSettings:MaxCitationSnippetLength", 250),
            ChunkSizeMode = ReadString("RagSettings:ChunkSizeMode", "Page"),
            PageChunkSize = ReadInt("RagSettings:PageChunkSize", 1),
            WordChunkSize = ReadInt("RagSettings:WordChunkSize", ReadInt("RagSettings:MaxChunkTokens", 700)),
            CharacterChunkSize = ReadInt("RagSettings:CharacterChunkSize", 3000),
            ChunkOverlapSize = ReadInt("RagSettings:ChunkOverlapSize", ReadInt("RagSettings:ChunkOverlapTokens", 100)),
            MinChunkCharacters = ReadInt("RagSettings:MinChunkCharacters", 30)
        };

        return NormalizeSettings(settings);
    }

    private string ReadString(string key, string fallback)
    {
        var value = _configuration[key];
        return string.IsNullOrWhiteSpace(value) ? fallback : value;
    }

    private int ReadInt(string key, int fallback)
    {
        return int.TryParse(_configuration[key], out var value) && value > 0
            ? value
            : fallback;
    }

    private decimal ReadDecimal(string key, decimal fallback)
    {
        return decimal.TryParse(_configuration[key], out var value)
            ? value
            : fallback;
    }

    private static SystemSettingsDto NormalizeSettings(SystemSettingsDto settings)
    {
        settings.EmbeddingProvider = string.IsNullOrWhiteSpace(settings.EmbeddingProvider) ? "Ollama" : settings.EmbeddingProvider.Trim();
        settings.EmbeddingModel = string.IsNullOrWhiteSpace(settings.EmbeddingModel) ? "bge-m3" : settings.EmbeddingModel.Trim();
        settings.ChunkSizeMode = NormalizeChunkSizeMode(settings.ChunkSizeMode);
        settings.PageChunkSize = Math.Clamp(settings.PageChunkSize, 1, 20);
        settings.WordChunkSize = Math.Clamp(settings.WordChunkSize, 50, 3000);
        settings.CharacterChunkSize = Math.Clamp(settings.CharacterChunkSize, 200, 20000);
        settings.ChunkOverlapSize = Math.Clamp(settings.ChunkOverlapSize, 0, 2000);
        settings.MinChunkCharacters = Math.Clamp(settings.MinChunkCharacters, 1, 1000);
        settings.ChatSystemPrompt ??= string.Empty;
        settings.EvaluationSystemPrompt ??= string.Empty;
        return settings;
    }

    private static string NormalizeChunkSizeMode(string? mode)
    {
        if (string.Equals(mode, "Page", StringComparison.OrdinalIgnoreCase))
        {
            return "Page";
        }

        if (string.Equals(mode, "Character", StringComparison.OrdinalIgnoreCase))
        {
            return "Character";
        }

        return "Word";
    }
}
