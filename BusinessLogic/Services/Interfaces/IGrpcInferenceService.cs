using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

public interface IGrpcInferenceService
{
    Task<ChatInferenceResultDto> ProcessChatMessageAsync(
        string userId,
        string sessionId,
        string prompt,
        CancellationToken cancellationToken = default);

    Task<VerificationResultDto> VerifyLegalDocumentAsync(
        string documentTitle,
        string documentNumber,
        string content,
        CancellationToken cancellationToken = default);

    Task<IndexDocumentResultDto> IndexDocumentAsync(
        IEnumerable<DocumentChunkInputDto> chunks,
        CancellationToken cancellationToken = default);
}
