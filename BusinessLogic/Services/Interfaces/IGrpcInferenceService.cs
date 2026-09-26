using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

/// <summary>
/// Abstraction cho gRPC Inference Service (Python).
/// Bao phủ toàn bộ 3 RPC trong chat_inference.proto:
///   - ProcessChatMessage  → Vương (Chat Service)
///   - VerifyLegalDocument → Phúc (Document Crawler / Cron Job)
///   - IndexDocument       → Phúc (Document Indexing / Cron Job)
/// </summary>
public interface IGrpcInferenceService
{
    /// <summary>
    /// [Vương] Gửi câu hỏi người dùng tới Python gRPC server; nhận lại
    /// câu trả lời RAG, citations và cờ vi phạm moderation.
    /// </summary>
    Task<ChatInferenceResultDto> ProcessChatMessageAsync(
        string userId,
        string sessionId,
        string prompt,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// [Phúc] Xác minh tính hiệu lực pháp lý của một văn bản luật giao thông.
    /// Dùng trong Cron Job cào văn bản từ thuvienphapluat.vn để kiểm tra
    /// văn bản còn hiệu lực hay đã bị thay thế / bãi bỏ.
    /// </summary>
    Task<VerificationResultDto> VerifyLegalDocumentAsync(
        string documentTitle,
        string documentNumber,
        string content = "",
        CancellationToken cancellationToken = default);

    /// <summary>
    /// [Phúc] Đẩy batch các chunks văn bản pháp lý vào Qdrant Vector DB.
    /// Dùng sau khi crawler cào xong tài liệu mới hoặc cron job cập nhật lại dữ liệu.
    /// </summary>
    Task<IndexDocumentResultDto> IndexDocumentAsync(
        IEnumerable<DocumentChunkInputDto> chunks,
        CancellationToken cancellationToken = default);
}

