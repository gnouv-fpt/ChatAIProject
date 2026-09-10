using System.ComponentModel.DataAnnotations;

namespace Presentation.Models;

public sealed class SystemSettingsViewModel
{
    public string EmbeddingProvider { get; set; } = "Ollama";
    public string EmbeddingModel { get; set; } = "bge-m3";
    public int TopK { get; set; } = 5;
    public decimal SimilarityThreshold { get; set; } = 0.7m;
    public int MaxCitationSnippetLength { get; set; } = 250;

    [Display(Name = "Kiểu chia chunk")]
    [RegularExpression("Page|Word|Character", ErrorMessage = "Kiểu chia chunk không hợp lệ.")]
    public string ChunkSizeMode { get; set; } = "Page";

    [Display(Name = "Số trang/slide mỗi chunk")]
    [Range(1, 20, ErrorMessage = "Số trang/slide mỗi chunk phải từ 1 đến 20.")]
    public int PageChunkSize { get; set; } = 1;

    [Display(Name = "Số từ mỗi chunk")]
    [Range(50, 3000, ErrorMessage = "Số từ mỗi chunk phải từ 50 đến 3000.")]
    public int WordChunkSize { get; set; } = 700;

    [Display(Name = "Số ký tự mỗi chunk")]
    [Range(200, 20000, ErrorMessage = "Số ký tự mỗi chunk phải từ 200 đến 20000.")]
    public int CharacterChunkSize { get; set; } = 3000;

    [Display(Name = "Overlap")]
    [Range(0, 2000, ErrorMessage = "Overlap phải từ 0 đến 2000.")]
    public int ChunkOverlapSize { get; set; } = 100;

    [Display(Name = "Độ dài tối thiểu")]
    [Range(1, 1000, ErrorMessage = "Độ dài tối thiểu phải từ 1 đến 1000 ký tự.")]
    public int MinChunkCharacters { get; set; } = 30;

    public string? ChatSystemPrompt { get; set; }
    public string? EvaluationSystemPrompt { get; set; }
    public string? SuccessMessage { get; set; }
    public string? ErrorMessage { get; set; }
}

public sealed class EmbeddingModelOptionViewModel
{
    public string Key { get; set; } = string.Empty;

    public string Provider { get; set; } = string.Empty;

    public string Model { get; set; } = string.Empty;

    public int Dimension { get; set; }

    public string Label => $"{Key} - {Provider} - {Dimension}d";
}
