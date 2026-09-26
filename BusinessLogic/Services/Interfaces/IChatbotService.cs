using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

public interface IChatbotService
{
    Task<ChatSessionResponseDto> CreateSessionAsync(
        Guid userId,
        CreateChatSessionRequest request,
        CancellationToken cancellationToken = default);

    Task<PagedResultDto<ChatSessionResponseDto>> GetSessionsAsync(
        Guid userId,
        int pageIndex,
        int pageSize,
        string? search = null,
        CancellationToken cancellationToken = default);

    Task<ChatSessionDetailResponseDto> GetSessionDetailAsync(
        Guid userId,
        Guid sessionId,
        CancellationToken cancellationToken = default);

    Task<ChatMessageResponseDto> SendMessageAsync(
        Guid userId,
        Guid sessionId,
        SendMessageRequest request,
        CancellationToken cancellationToken = default);

    Task DeleteSessionAsync(
        Guid userId,
        Guid sessionId,
        CancellationToken cancellationToken = default);
}
