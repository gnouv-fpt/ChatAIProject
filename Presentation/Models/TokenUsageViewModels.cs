namespace Presentation.Models;

public sealed class TokenUsageSummaryViewModel
{
    public int PromptTokens { get; set; }
    public int CompletionTokens { get; set; }
    public int TotalTokens { get; set; }
    public int AnswerCount { get; set; }
    public DateTime? FirstUsedAt { get; set; }
    public DateTime? LastUsedAt { get; set; }
}

public sealed class UserTokenUsageViewModel
{
    public int UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public int PromptTokens { get; set; }
    public int CompletionTokens { get; set; }
    public int TotalTokens { get; set; }
    public int AnswerCount { get; set; }
    public DateTime? LastUsedAt { get; set; }
}

public sealed class AdminTokenUsageViewModel
{
    public TokenUsageSummaryViewModel Summary { get; set; } = new();
    public List<UserTokenUsageViewModel> Users { get; set; } = new();
    public EmbeddingTokenUsageChartViewModel EmbeddingUsage { get; set; } = new();
    public DailyEmbeddingTokenUsageChartViewModel DailyEmbeddingUsage { get; set; } = new();
}

public sealed class EmbeddingTokenUsageChartViewModel
{
    public List<EmbeddingModelTokenUsageViewModel> Today { get; set; } = new();
    public List<EmbeddingModelTokenUsageViewModel> ThisWeek { get; set; } = new();
    public List<EmbeddingModelTokenUsageViewModel> ThisMonth { get; set; } = new();
}

public sealed class EmbeddingModelTokenUsageViewModel
{
    public string EmbeddingModel { get; set; } = string.Empty;
    public int TokenCount { get; set; }
    public int EmbeddingCount { get; set; }
}

public sealed class DailyEmbeddingTokenUsageChartViewModel
{
    public List<string> Labels { get; set; } = new();
    public List<DailyEmbeddingTokenUsageSeriesViewModel> Series { get; set; } = new();
    public int MaxTokenCount { get; set; }
}

public sealed class DailyEmbeddingTokenUsageSeriesViewModel
{
    public string EmbeddingModel { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public List<int> Values { get; set; } = new();
}
