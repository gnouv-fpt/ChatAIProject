namespace BusinessLogic.Services.Interfaces;

using BusinessLogic.DTOs.Responses;

public interface ILlmService
{
    string ModelName { get; }

    Task<LlmResponseDto> GenerateAnswerAsync(string prompt, CancellationToken cancellationToken = default);
}
