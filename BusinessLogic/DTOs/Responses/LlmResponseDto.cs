namespace BusinessLogic.DTOs.Responses;

public sealed record LlmResponseDto(
    string Text,
    int? PromptTokens,
    int? CompletionTokens)
{
    public int TotalTokens => (PromptTokens ?? 0) + (CompletionTokens ?? 0);
}
