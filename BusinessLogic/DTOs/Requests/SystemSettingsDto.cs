namespace BusinessLogic.DTOs.Requests;

public sealed class SystemSettingsDto
{
    public string EmbeddingProvider { get; set; } = "Ollama";
    public string EmbeddingModel { get; set; } = "bge-m3";
    public int TopK { get; set; } = 5;
    public decimal SimilarityThreshold { get; set; } = 0.7m;
    public int MaxCitationSnippetLength { get; set; } = 250;
    public string ChunkSizeMode { get; set; } = "Page";
    public int PageChunkSize { get; set; } = 1;
    public int WordChunkSize { get; set; } = 700;
    public int CharacterChunkSize { get; set; } = 3000;
    public int ChunkOverlapSize { get; set; } = 100;
    public int MinChunkCharacters { get; set; } = 30;
    public string ChatSystemPrompt { get; set; } = string.Empty;
    public string EvaluationSystemPrompt { get; set; } = string.Empty;
}
