using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Events;
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
    private readonly IChatTurnRepository _turns;
    private readonly IAttachmentService _attachments;
    private readonly ChatSettings _settings;
    private readonly ILogger<ChatbotService> _logger;

    public ChatbotService(
        IChatSessionRepository chatSessionRepository,
        IChatMessageRepository chatMessageRepository,
        IUserRepository userRepository,
        IGrpcInferenceService grpcInferenceService,
        IChatTurnRepository turns,
        IAttachmentService attachments,
        ChatSettings settings,
        ILogger<ChatbotService> logger)
    {
        _chatSessionRepository = chatSessionRepository;
        _chatMessageRepository = chatMessageRepository;
        _userRepository = userRepository;
        _grpcInferenceService = grpcInferenceService;
        _turns = turns;
        _attachments = attachments;
        _settings = settings;
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
        pageIndex = Math.Min(pageIndex, int.MaxValue / pageSize);

        var (items, totalCount) = await _chatSessionRepository.GetUserSessionsPagedAsync(
            userId, pageIndex, pageSize, search, cancellationToken);
        var messageCounts = await _turns.CountMessagesAsync(items.Select(s => s.Id).ToArray(), cancellationToken);

        var dtos = items.Select(s => new ChatSessionResponseDto
        {
            Id = s.Id,
            Title = s.Title,
            CreatedAt = s.CreatedAt,
            LastUpdatedAt = s.LastUpdatedAt,
            MessageCount = messageCounts.GetValueOrDefault(s.Id)
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
            Messages = session.Messages.Where(m => m.TurnState == null || m.TurnState == "Completed").Select(m => new ChatMessageResponseDto
            {
                Id = m.Id,
                RequestId = m.RequestId,
                Status = m.ResultStatus ?? "Answered",
                AttachmentIds = ParseAttachments(m.RequestContext),
                SessionId = m.SessionId,
                SenderRole = m.SenderRole,
                Content = m.Content,
                TokensUsed = m.TokensUsed,
                IsViolation = m.IsViolation,
                CreatedAt = m.CreatedAt,
                Citations = m.Citations.Select(c => new CitationResponseDto
                {
                    Id = c.Id,
                    DocumentChunkId = c.DocumentChunkId,
                    ContentHash = c.ContentHash,
                    PointNumber = c.PointNumber,
                    DocumentTitle = c.DocumentTitle,
                    ArticleNumber = c.ArticleNumber,
                    ClauseNumber = c.ClauseNumber,
                    Excerpt = c.Excerpt,
                    SourceUrl = c.SourceUrl
                }).ToList()
            }).ToList()
        };
    }

    public async Task<ChatMessageResponseDto> SendMessageAsync(Guid userId, Guid sessionId,
        SendMessageRequest request, CancellationToken cancellationToken = default)
    {
        var started = System.Diagnostics.Stopwatch.StartNew();
        try
        {
            var result = await SendTurnCoreAsync(userId, sessionId, request, cancellationToken);
            BusinessLogic.Infrastructure.ChatTelemetry.Requests.Add(1, new KeyValuePair<string, object?>("outcome", result.Status));
            return result;
        }
        catch
        {
            BusinessLogic.Infrastructure.ChatTelemetry.Requests.Add(1, new KeyValuePair<string, object?>("outcome", "error"));
            throw;
        }
        finally { BusinessLogic.Infrastructure.ChatTelemetry.Duration.Record(started.Elapsed.TotalSeconds); }
    }

    private async Task<ChatMessageResponseDto> SendTurnCoreAsync(Guid userId, Guid sessionId,
        SendMessageRequest request, CancellationToken cancellationToken = default)
    {
        if (request.RequestId == Guid.Empty) throw new BadRequestException("Cần requestId để gửi lại an toàn.");
        if (string.IsNullOrWhiteSpace(request.Prompt) || request.Prompt.Length > 2000)
            throw new BadRequestException("Câu hỏi phải từ 1 đến 2000 ký tự.");
        if (request.AttachmentIds is null || request.AttachmentIds.Length > 3 || request.AttachmentIds.Any(id => id == Guid.Empty))
            throw new BadRequestException("Danh sách ảnh không hợp lệ.");
        var prompt = request.Prompt.Trim();
        var hash = Hash(JsonSerializer.Serialize(new { prompt, images = request.AttachmentIds.Distinct().Order().ToArray(), usePreviousAttachments = request.UsePreviousAttachments }));
        var leaseId = Guid.NewGuid();
        var turn = await _turns.WithUserLockAsync(userId, async () =>
        {
            var session = await RequireSessionAsync(userId, sessionId, cancellationToken);
            var existing = await _turns.GetTurnAsync(sessionId, request.RequestId, cancellationToken);
            if (existing != null)
            {
                if (existing.RequestHash != hash) throw new ConflictException("requestId đã dùng cho nội dung khác.");
                if (existing.TurnState == "Completed")
                {
                    await ValidateStoredCitationsAsync(existing, cancellationToken);
                    return existing;
                }
                if (existing.TurnState == "Processing" && existing.LeaseExpiresAt > DateTime.UtcNow)
                    throw new ConflictException("Câu hỏi này đang được xử lý. Vui lòng thử lại cùng requestId.");
            }
            var user = await _userRepository.GetByIdAsync(userId, cancellationToken)
                ?? throw new UnauthorizedException("Người dùng không tồn tại.");
            var reservations = await _turns.GetReservationsAsync(userId, cancellationToken);
            var held = reservations.Where(m => m.Id != existing?.Id &&
                (m.TurnState == "Completed" || m.LeaseExpiresAt > DateTime.UtcNow)).Sum(m => (long)m.ReservedTokens);
            var available = user.TokenBalance - held;
            if (available <= 0) throw new QuotaExceededException("Bạn đã hết quota khả dụng hoặc có yêu cầu đang chờ quyết toán.");
            var images = request.AttachmentIds.Distinct().ToArray();
            if (images.Length == 0 && request.UsePreviousAttachments)
            {
                var previous = await _turns.GetContextAsync(sessionId, cancellationToken);
                images = ParseAttachments(previous.FirstOrDefault(m => m.SenderRole == SenderRole.Assistant)?.RequestContext);
            }
            var message = existing ?? new ChatMessage
            {
                Id = Guid.NewGuid(), SessionId = sessionId, RequestId = request.RequestId,
                SenderRole = SenderRole.Assistant, Content = "", CreatedAt = DateTime.UtcNow
            };
            message.RequestHash = hash;
            message.RequestContext = JsonSerializer.Serialize(images);
            message.TurnState = "Processing";
            message.LeaseId = leaseId;
            message.LeaseExpiresAt = DateTime.UtcNow.AddSeconds(_settings.InferenceTimeoutSeconds + 30);
            message.ReservedTokens = (int)Math.Min(available, _settings.ReservationTokens);
            if (existing == null) await _chatMessageRepository.AddAsync(message, cancellationToken);
            return message;
        }, cancellationToken);
        if (turn.TurnState == "Completed") return MapMessage(turn);

        try
        {
            var images = new List<ChatImageDto>();
            foreach (var id in ParseAttachments(turn.RequestContext))
                images.Add(await _attachments.ReadAsync(userId, sessionId, id, cancellationToken));
            var previous = await _turns.GetContextAsync(sessionId, cancellationToken);
            var history = previous.OrderBy(m => m.CreatedAt).Select(m => new ChatHistoryDto(
                m.SenderRole == SenderRole.User ? "user" : "assistant", m.Content)).ToArray();
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            deadline.CancelAfter(TimeSpan.FromSeconds(_settings.InferenceTimeoutSeconds));
            ChatInferenceResultDto result;
            try
            {
                result = await _grpcInferenceService.ProcessTurnAsync(new(userId, sessionId, request.RequestId,
                    prompt, images, history, turn.ReservedTokens), deadline.Token);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                throw new UpstreamTimeoutException("Dịch vụ AI phản hồi quá chậm. Vui lòng thử lại cùng requestId.");
            }
            ValidateResult(result, images.Count > 0);
            // No DB transaction is held during inference. Completion rechecks current SQL evidence.
            var completed = await _turns.WithUserLockAsync(userId, async () =>
            {
                var session = await RequireSessionAsync(userId, sessionId, cancellationToken);
                var current = await _turns.GetTurnAsync(sessionId, request.RequestId, cancellationToken)
                    ?? throw new ConflictException("Không tìm thấy lượt chat.");
                if (current.LeaseId != leaseId || current.TurnState != "Processing" || current.LeaseExpiresAt <= DateTime.UtcNow)
                    throw new ConflictException("Lượt chat đã hết hạn. Vui lòng gửi lại cùng requestId.");
                var citations = await ValidateCitationsAsync(result.Citations, cancellationToken);
                current.Content = result.ResponseText;
                current.TokensUsed = result.TokensUsed;
                current.IsViolation = result.IsViolation;
                current.ResultStatus = result.Status;
                current.Citations = citations;
                _turns.AddCitations(citations);
                current.TurnState = "Completed";
                current.CreatedAt = DateTime.UtcNow;
                // Holds actual usage until the Worker's atomic balance/settlement transaction.
                // Provider overrun remains accounted for, even if it exceeds the reservation.
                current.ReservedTokens = result.TokensUsed;
                current.LeaseExpiresAt = null;
                var completedEvent = new ChatCompletedEvent
                {
                    EventId = current.Id, MessageId = current.Id, RequestId = request.RequestId,
                    UserId = userId, SessionId = sessionId, Prompt = prompt, Response = result.ResponseText,
                    TokensUsed = result.TokensUsed, IsViolation = result.IsViolation,
                    ViolationKeywords = result.ViolationKeywords, TraceParent = System.Diagnostics.Activity.Current?.Id,
                    CreatedAt = DateTime.UtcNow
                };
                current.EventPayload = JsonSerializer.Serialize(completedEvent);
                await _chatMessageRepository.AddAsync(new ChatMessage
                {
                    Id = Guid.NewGuid(), SessionId = sessionId, SenderRole = SenderRole.User,
                    Content = prompt, RequestContext = current.RequestContext, CreatedAt = turn.CreatedAt
                }, cancellationToken);
                session.LastUpdatedAt = current.CreatedAt;
                return current;
            }, cancellationToken);
            _logger.LogInformation("Chat turn completed: {MessageId}, {ResultStatus}, {TokensUsed}", completed.Id, completed.ResultStatus, completed.TokensUsed);
            BusinessLogic.Infrastructure.ChatTelemetry.Tokens.Add(completed.TokensUsed);
            return MapMessage(completed);
        }
        catch
        {
            // Do not let HTTP cancellation prevent releasing a reservation. Fenced by lease ID.
            using var releaseDeadline = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            try
            {
                await _turns.WithUserLockAsync(userId, async () =>
                {
                    var current = await _turns.GetTurnAsync(sessionId, request.RequestId, releaseDeadline.Token);
                    if (current?.LeaseId == leaseId && current.TurnState == "Processing")
                    {
                        current.TurnState = "Failed";
                        current.ReservedTokens = 0;
                        current.LeaseExpiresAt = null;
                    }
                    return true;
                }, releaseDeadline.Token);
            }
            catch (Exception ex) { _logger.LogError(ex, "Reservation release deferred to lease expiry: {RequestId}", request.RequestId); }
            throw;
        }
    }

    private async Task<ChatSession> RequireSessionAsync(Guid userId, Guid sessionId, CancellationToken ct)
    {
        var session = await _chatSessionRepository.GetByIdAsync(sessionId, ct);
        if (session == null || session.UserId != userId || session.IsDeleted)
            throw new NotFoundException("Không tìm thấy phiên chat.");
        return session;
    }

    public static void ValidateResult(ChatInferenceResultDto result, bool hasImages)
    {
        if (result.ContractVersion < 2 || (hasImages && !result.ImagesProcessed))
            throw new ServiceUnavailableException("Dịch vụ AI chưa hỗ trợ hợp đồng chat yêu cầu.");
        if (result.TokensUsed < 0 || string.IsNullOrWhiteSpace(result.ResponseText) || result.ResponseText.Length > 32000 ||
            result.Status is not ("Answered" or "NoMatch" or "Blocked" or "NeedsClarification") ||
            (result.Status == "Blocked") != result.IsViolation ||
            (result.Status == "Answered" && (!result.DataVerified || result.Citations.Count == 0)))
            throw new ServiceUnavailableException("Phản hồi AI không hợp lệ hoặc chưa có căn cứ pháp lý xác thực.");
    }

    private async Task<List<Citation>> ValidateCitationsAsync(List<CitationResultDto> citations, CancellationToken ct)
    {
        if (citations.Any(c => !Guid.TryParse(c.ChunkId, out _)))
            throw new ServiceUnavailableException("Trích dẫn AI thiếu mã đoạn văn bản SQL.");
        var ids = citations.Select(c => Guid.Parse(c.ChunkId)).Distinct().ToArray();
        var chunks = await _turns.GetChunksAsync(ids, ct);
        var output = new List<Citation>();
        foreach (var citation in citations)
        {
            var chunk = chunks.SingleOrDefault(c => c.Id == Guid.Parse(citation.ChunkId));
            if (chunk == null || !IsEligible(chunk) || Hash(chunk.Content) != citation.ContentHash ||
                chunk.Document.Title != citation.DocumentTitle || chunk.Document.SourceUrl != citation.SourceUrl ||
                (chunk.Article ?? "") != citation.ArticleNumber || (chunk.Clause ?? "") != citation.ClauseNumber || (chunk.Point ?? "") != citation.PointNumber ||
                string.IsNullOrWhiteSpace(citation.Excerpt) || !chunk.Content.Contains(citation.Excerpt, StringComparison.Ordinal))
                throw new ConflictException("Căn cứ pháp lý đã thay đổi hoặc không khớp. Vui lòng hỏi lại.");
            output.Add(new Citation
            {
                Id = Guid.NewGuid(), DocumentChunkId = chunk.Id, ContentHash = citation.ContentHash,
                DocumentTitle = chunk.Document.Title, ArticleNumber = chunk.Article, ClauseNumber = chunk.Clause,
                PointNumber = citation.PointNumber, Excerpt = citation.Excerpt, SourceUrl = chunk.Document.SourceUrl
            });
        }
        return output;
    }

    private async Task ValidateStoredCitationsAsync(ChatMessage message, CancellationToken ct)
    {
        await ValidateCitationsAsync(message.Citations.Select(c => new CitationResultDto
        {
            ChunkId = c.DocumentChunkId?.ToString() ?? "", ContentHash = c.ContentHash ?? "",
            DocumentTitle = c.DocumentTitle ?? "", ArticleNumber = c.ArticleNumber ?? "",
            ClauseNumber = c.ClauseNumber ?? "", SourceUrl = c.SourceUrl ?? "", Excerpt = c.Excerpt ?? "", PointNumber = c.PointNumber ?? ""
        }).ToList(), ct);
    }

    public static bool IsEligible(DocumentChunk chunk) => chunk.IsVerified && chunk.Document.IsActive &&
        chunk.Document.VerificationStatus == VerificationStatus.Verified &&
        (chunk.Document.EffectiveDate == null || chunk.Document.EffectiveDate <= DateTime.UtcNow) &&
        (chunk.Document.ExpirationDate == null || chunk.Document.ExpirationDate > DateTime.UtcNow) &&
        Uri.TryCreate(chunk.Document.SourceUrl, UriKind.Absolute, out var source) && source.Scheme == "https" &&
        (source.Host == "thuvienphapluat.vn" || source.Host.EndsWith(".thuvienphapluat.vn", StringComparison.OrdinalIgnoreCase));

    public static string Hash(string content) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(content))).ToLowerInvariant();
    private static Guid[] ParseAttachments(string? json) => json == null ? [] : JsonSerializer.Deserialize<Guid[]>(json) ?? [];
    private static ChatMessageResponseDto MapMessage(ChatMessage m) => new()
    {
        Id = m.Id, RequestId = m.RequestId, SessionId = m.SessionId, Content = m.Content,
        SenderRole = m.SenderRole, TokensUsed = m.TokensUsed, IsViolation = m.IsViolation,
        CreatedAt = m.CreatedAt, Status = m.ResultStatus ?? "Answered", AttachmentIds = ParseAttachments(m.RequestContext),
        Citations = m.Citations.Select(c => new CitationResponseDto
        {
            Id = c.Id, DocumentChunkId = c.DocumentChunkId, ContentHash = c.ContentHash, PointNumber = c.PointNumber,
            DocumentTitle = c.DocumentTitle, ArticleNumber = c.ArticleNumber, ClauseNumber = c.ClauseNumber,
            Excerpt = c.Excerpt, SourceUrl = c.SourceUrl
        }).ToList()
    };

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
