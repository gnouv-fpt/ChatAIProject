using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Events;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public class ChatbotService : IChatbotService
{
    private readonly IChatSessionRepository _chatSessionRepository;
    private readonly IChatMessageRepository _chatMessageRepository;
    private readonly IUserRepository _userRepository;
    private readonly IGrpcInferenceService _grpcInferenceService;
    private readonly IEventPublisher _eventPublisher;
    private readonly ILogger<ChatbotService> _logger;

    public ChatbotService(
        IChatSessionRepository chatSessionRepository,
        IChatMessageRepository chatMessageRepository,
        IUserRepository userRepository,
        IGrpcInferenceService grpcInferenceService,
        IEventPublisher eventPublisher,
        ILogger<ChatbotService> logger)
    {
        _chatSessionRepository = chatSessionRepository;
        _chatMessageRepository = chatMessageRepository;
        _userRepository = userRepository;
        _grpcInferenceService = grpcInferenceService;
        _eventPublisher = eventPublisher;
        _logger = logger;
    }

    public async Task<ChatSessionResponseDto> CreateSessionAsync(
        Guid userId,
        CreateChatSessionRequest request,
        CancellationToken cancellationToken = default)
    {
        var title = string.IsNullOrWhiteSpace(request.Title)
            ? $"Tư vấn luật {DateTime.UtcNow:dd/MM/yyyy HH:mm}"
            : request.Title.Trim();

        var session = new ChatSession
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Title = title,
            CreatedAt = DateTime.UtcNow,
            LastUpdatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        await _chatSessionRepository.AddAsync(session, cancellationToken);
        await _chatSessionRepository.SaveChangesAsync(cancellationToken);

        return new ChatSessionResponseDto
        {
            Id = session.Id,
            Title = session.Title,
            CreatedAt = session.CreatedAt,
            LastUpdatedAt = session.LastUpdatedAt,
            MessageCount = 0
        };
    }

    public async Task<PagedResultDto<ChatSessionResponseDto>> GetSessionsAsync(
        Guid userId,
        int pageIndex,
        int pageSize,
        string? search = null,
        CancellationToken cancellationToken = default)
    {
        if (pageIndex < 1) pageIndex = 1;
        if (pageSize < 1) pageSize = 10;
        if (pageSize > 50) pageSize = 50;

        var (items, totalCount) = await _chatSessionRepository.GetUserSessionsPagedAsync(
            userId, pageIndex, pageSize, search, cancellationToken);

        var dtos = items.Select(s => new ChatSessionResponseDto
        {
            Id = s.Id,
            Title = s.Title,
            CreatedAt = s.CreatedAt,
            LastUpdatedAt = s.LastUpdatedAt,
            MessageCount = s.Messages?.Count ?? 0
        }).ToList();

        return new PagedResultDto<ChatSessionResponseDto>
        {
            Items = dtos,
            TotalCount = totalCount,
            PageIndex = pageIndex,
            PageSize = pageSize
        };
    }

    public async Task<ChatSessionDetailResponseDto> GetSessionDetailAsync(
        Guid userId,
        Guid sessionId,
        CancellationToken cancellationToken = default)
    {
        var session = await _chatSessionRepository.GetSessionWithMessagesAsync(sessionId, userId, cancellationToken);
        if (session == null)
        {
            throw new NotFoundException("Không tìm thấy phiên hỏi đáp hoặc bạn không có quyền truy cập.");
        }

        return new ChatSessionDetailResponseDto
        {
            Id = session.Id,
            Title = session.Title,
            CreatedAt = session.CreatedAt,
            LastUpdatedAt = session.LastUpdatedAt,
            Messages = session.Messages.Select(m => new ChatMessageResponseDto
            {
                Id = m.Id,
                SessionId = m.SessionId,
                SenderRole = m.SenderRole,
                Content = m.Content,
                TokensUsed = m.TokensUsed,
                IsViolation = m.IsViolation,
                CreatedAt = m.CreatedAt,
                Citations = m.Citations.Select(c => new CitationResponseDto
                {
                    Id = c.Id,
                    DocumentTitle = c.DocumentTitle,
                    ArticleNumber = c.ArticleNumber,
                    ClauseNumber = c.ClauseNumber,
                    Excerpt = c.Excerpt,
                    SourceUrl = c.SourceUrl
                }).ToList()
            }).ToList()
        };
    }

    public async Task<ChatMessageResponseDto> SendMessageAsync(
        Guid userId,
        Guid sessionId,
        SendMessageRequest request,
        CancellationToken cancellationToken = default)
    {
        var session = await _chatSessionRepository.GetByIdAsync(sessionId, cancellationToken);
        if (session == null || session.UserId != userId || session.IsDeleted)
        {
            throw new NotFoundException("Không tìm thấy phiên hỏi đáp hoặc phiên đã bị xóa.");
        }

        var user = await _userRepository.GetByIdAsync(userId, cancellationToken);
        if (user == null)
        {
            throw new UnauthorizedException("Người dùng không tồn tại.");
        }

        // 1. Lưu tin nhắn của người dùng
        var userMessage = new ChatMessage
        {
            Id = Guid.NewGuid(),
            SessionId = sessionId,
            SenderRole = SenderRole.User,
            Content = request.Prompt.Trim(),
            TokensUsed = 0,
            IsViolation = false,
            CreatedAt = DateTime.UtcNow
        };
        await _chatMessageRepository.AddAsync(userMessage, cancellationToken);

        // 2. Gọi gRPC Inference Service (Moderation + RAG)
        var grpcResult = await _grpcInferenceService.ProcessChatMessageAsync(
            userId.ToString(),
            sessionId.ToString(),
            request.Prompt.Trim(),
            cancellationToken);

        // 3. Lưu tin nhắn trả lời của Assistant kèm Citations
        var assistantMessage = new ChatMessage
        {
            Id = Guid.NewGuid(),
            SessionId = sessionId,
            SenderRole = SenderRole.Assistant,
            Content = grpcResult.ResponseText,
            TokensUsed = grpcResult.TokensUsed,
            IsViolation = grpcResult.IsViolation,
            CreatedAt = DateTime.UtcNow,
            Citations = grpcResult.Citations.Select(c => new Citation
            {
                Id = Guid.NewGuid(),
                DocumentTitle = c.DocumentTitle,
                ArticleNumber = c.ArticleNumber,
                ClauseNumber = c.ClauseNumber,
                Excerpt = c.Excerpt,
                SourceUrl = c.SourceUrl
            }).ToList()
        };
        await _chatMessageRepository.AddAsync(assistantMessage, cancellationToken);

        // 4. Cập nhật thời gian phiên chat
        session.LastUpdatedAt = DateTime.UtcNow;
        _chatSessionRepository.Update(session);

        // Persist DB changes
        await _chatMessageRepository.SaveChangesAsync(cancellationToken);

        // 5. Đẩy sự kiện bất đồng bộ sang Message Broker (Redis Pub/Sub) cho Worker tiêu thụ
        var chatCompletedEvent = new ChatCompletedEvent
        {
            UserId = userId,
            SessionId = sessionId,
            Prompt = request.Prompt.Trim(),
            Response = grpcResult.ResponseText,
            TokensUsed = grpcResult.TokensUsed,
            IsViolation = grpcResult.IsViolation,
            ViolationKeywords = grpcResult.ViolationKeywords,
            CreatedAt = DateTime.UtcNow
        };

        try
        {
            await _eventPublisher.PublishAsync("chat-completed-events", chatCompletedEvent, cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi publish event ChatCompletedEvent cho sessionId {SessionId}", sessionId);
        }

        // 6. Trả kết quả response cho client
        return new ChatMessageResponseDto
        {
            Id = assistantMessage.Id,
            SessionId = sessionId,
            SenderRole = assistantMessage.SenderRole,
            Content = assistantMessage.Content,
            TokensUsed = assistantMessage.TokensUsed,
            IsViolation = assistantMessage.IsViolation,
            CreatedAt = assistantMessage.CreatedAt,
            Citations = assistantMessage.Citations.Select(c => new CitationResponseDto
            {
                Id = c.Id,
                DocumentTitle = c.DocumentTitle,
                ArticleNumber = c.ArticleNumber,
                ClauseNumber = c.ClauseNumber,
                Excerpt = c.Excerpt,
                SourceUrl = c.SourceUrl
            }).ToList()
        };
    }

    public async Task DeleteSessionAsync(
        Guid userId,
        Guid sessionId,
        CancellationToken cancellationToken = default)
    {
        var success = await _chatSessionRepository.SoftDeleteSessionAsync(sessionId, userId, cancellationToken);
        if (!success)
        {
            throw new NotFoundException("Không tìm thấy phiên hỏi đáp để xóa.");
        }

        await _chatSessionRepository.SaveChangesAsync(cancellationToken);
    }
}
