using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.SystemSettings;

[Authorize(Roles = "Admin")]
public sealed class IndexModel : AppPageModel
{
    private readonly ISystemSettingsService _settingsService;
    private readonly IEmbeddingModelRegistry _embeddingModelRegistry;

    public IndexModel(
        ISystemSettingsService settingsService,
        IEmbeddingModelRegistry embeddingModelRegistry)
    {
        _settingsService = settingsService;
        _embeddingModelRegistry = embeddingModelRegistry;
    }

    [BindProperty]
    public SystemSettingsViewModel ViewModel { get; set; } = new();

    public IReadOnlyList<EmbeddingModelOptionViewModel> EmbeddingModels { get; private set; } = [];

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        await LoadSettingsAsync(cancellationToken);

        if (TempData["SuccessMessage"] != null)
        {
            ViewModel.SuccessMessage = TempData["SuccessMessage"]?.ToString();
        }

        if (TempData["ErrorMessage"] != null)
        {
            ViewModel.ErrorMessage = TempData["ErrorMessage"]?.ToString();
        }
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        LoadEmbeddingModels();
        if (!ModelState.IsValid)
        {
            return Page();
        }

        var selectedEmbeddingModel = ResolveSelectedEmbeddingModel(ViewModel.EmbeddingModel);
        if (selectedEmbeddingModel is null)
        {
            ModelState.AddModelError("ViewModel.EmbeddingModel", "Model embedding không hợp lệ.");
            return Page();
        }

        var settings = CreateSettingsDto(selectedEmbeddingModel);
        await _settingsService.SaveSettingsAsync(settings, cancellationToken);

        TempData["SuccessMessage"] = "Lưu cấu hình hệ thống thành công!";
        return RedirectToPage("/SystemSettings/Index");
    }

    private async Task LoadSettingsAsync(CancellationToken cancellationToken)
    {
        LoadEmbeddingModels();
        var settings = await _settingsService.GetSettingsAsync(cancellationToken);
        var selectedEmbeddingModel = ResolveSelectedEmbeddingModel(settings.EmbeddingModel) ?? EmbeddingModels.FirstOrDefault();

        ViewModel = new SystemSettingsViewModel
        {
            EmbeddingProvider = selectedEmbeddingModel?.Provider ?? settings.EmbeddingProvider,
            EmbeddingModel = selectedEmbeddingModel?.Key ?? EmbeddingModels.FirstOrDefault()?.Key ?? settings.EmbeddingModel,
            TopK = settings.TopK,
            SimilarityThreshold = settings.SimilarityThreshold,
            MaxCitationSnippetLength = settings.MaxCitationSnippetLength,
            ChunkSizeMode = settings.ChunkSizeMode,
            PageChunkSize = settings.PageChunkSize,
            WordChunkSize = settings.WordChunkSize,
            CharacterChunkSize = settings.CharacterChunkSize,
            ChunkOverlapSize = settings.ChunkOverlapSize,
            MinChunkCharacters = settings.MinChunkCharacters,
            ChatSystemPrompt = settings.ChatSystemPrompt,
            EvaluationSystemPrompt = settings.EvaluationSystemPrompt
        };
    }

    private SystemSettingsDto CreateSettingsDto(EmbeddingModelOptionViewModel selectedEmbeddingModel)
    {
        return new SystemSettingsDto
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
    }

    private void LoadEmbeddingModels()
    {
        EmbeddingModels = _embeddingModelRegistry.GetAvailableModels()
            .Where(model => !string.Equals(model.Provider, "Fake", StringComparison.OrdinalIgnoreCase))
            .Select(model => new EmbeddingModelOptionViewModel
            {
                Key = model.Key,
                Provider = model.Provider,
                Model = model.Model,
                Dimension = model.Dimension
            })
            .ToList();
    }

    private EmbeddingModelOptionViewModel? ResolveSelectedEmbeddingModel(string? modelKey)
    {
        return EmbeddingModels.FirstOrDefault(model =>
            string.Equals(model.Key, modelKey, StringComparison.OrdinalIgnoreCase));
    }
}
