using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.SystemSettings;

[Authorize(Roles = "Admin")]
public sealed class SaveModel : AppPageModel
{
    private readonly ISystemSettingsService _settingsService;
    private readonly IEmbeddingModelRegistry _embeddingModelRegistry;

    public SaveModel(
        ISystemSettingsService settingsService,
        IEmbeddingModelRegistry embeddingModelRegistry)
    {
        _settingsService = settingsService;
        _embeddingModelRegistry = embeddingModelRegistry;
    }

    [BindProperty]
    public SystemSettingsViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            TempData["ErrorMessage"] = "Cấu hình không hợp lệ. Vui lòng kiểm tra lại.";
            return RedirectToPage("/SystemSettings/Index");
        }

        var selectedEmbeddingModel = ResolveSelectedEmbeddingModel(ViewModel.EmbeddingModel);
        if (selectedEmbeddingModel is null)
        {
            TempData["ErrorMessage"] = "Model embedding không hợp lệ hoặc đã bị tắt.";
            return RedirectToPage("/SystemSettings/Index");
        }

        var settings = new SystemSettingsDto
        {
            EmbeddingProvider = selectedEmbeddingModel.Provider,
            EmbeddingModel = selectedEmbeddingModel.Key,
            TopK = ViewModel.TopK,
            SimilarityThreshold = ViewModel.SimilarityThreshold,
            MaxCitationSnippetLength = ViewModel.MaxCitationSnippetLength,
            ChunkSizeMode = ViewModel.ChunkSizeMode,
            PageChunkSize = ViewModel.PageChunkSize,
            WordChunkSize = ViewModel.WordChunkSize,
            CharacterChunkSize = ViewModel.CharacterChunkSize,
            ChunkOverlapSize = ViewModel.ChunkOverlapSize,
            MinChunkCharacters = ViewModel.MinChunkCharacters,
            ChatSystemPrompt = ViewModel.ChatSystemPrompt ?? string.Empty,
            EvaluationSystemPrompt = ViewModel.EvaluationSystemPrompt ?? string.Empty
        };

        await _settingsService.SaveSettingsAsync(settings, cancellationToken);

        TempData["SuccessMessage"] = "Lưu cấu hình hệ thống thành công!";
        return RedirectToPage("/SystemSettings/Index");
    }

    private EmbeddingModelOptionViewModel? ResolveSelectedEmbeddingModel(string? modelKey)
    {
        return _embeddingModelRegistry.GetAvailableModels()
            .Where(model => !string.Equals(model.Provider, "Fake", StringComparison.OrdinalIgnoreCase))
            .Select(model => new EmbeddingModelOptionViewModel
            {
                Key = model.Key,
                Provider = model.Provider,
                Model = model.Model,
                Dimension = model.Dimension
            })
            .FirstOrDefault(model => string.Equals(model.Key, modelKey, StringComparison.OrdinalIgnoreCase));
    }
}
