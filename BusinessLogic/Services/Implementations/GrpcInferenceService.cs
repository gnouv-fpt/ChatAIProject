using BusinessLogic.DTOs;
using BusinessLogic.Protos;
using BusinessLogic.Services.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

/// <summary>
/// Gọi Python gRPC Inference Service qua Grpc.Net.Client.
/// Đây là lớp duy nhất trong .NET biết về generated Protobuf types.
/// <para>
/// ⚠️ LƯU Ý — Vector Dimension Mismatch Risk:
/// Python EmbeddingEngine dùng DIMENSION=768 khi có GOOGLE_API_KEY (Gemini),
/// hoặc DIMENSION=384 khi chạy offline (SentenceTransformers / builtin).
/// Nếu Qdrant collection đã được tạo với 768d (Gemini) rồi sau đó server khởi động
/// lại không có API key (fallback 384d), các lần upsert/search sẽ lỗi vector size mismatch.
/// → Giải pháp: Đảm bảo biến môi trường GOOGLE_API_KEY nhất quán giữa các lần khởi động,
///   hoặc xoá collection Qdrant và seed lại khi đổi embedding provider.
/// </para>
/// </summary>
public class GrpcInferenceService(
    TrafficRagInference.TrafficRagInferenceClient grpcClient,
    ILogger<GrpcInferenceService> logger) : IGrpcInferenceService
{
    // ─────────────────────────────────────────────────────────────────────────
    // Vương: Chat inference + RAG
    // ─────────────────────────────────────────────────────────────────────────

    public async Task<ChatInferenceResultDto> ProcessChatMessageAsync(
        string userId,
        string sessionId,
        string prompt,
        CancellationToken cancellationToken = default)
    {
        logger.LogInformation(
            "Calling gRPC ProcessChatMessage for user {UserId}, session {SessionId}",
            userId, sessionId);

        var request = new ChatInferenceRequest
        {
            UserId = userId,
            SessionId = sessionId,
            Prompt = prompt
        };

        var response = await grpcClient.ProcessChatMessageAsync(
            request, cancellationToken: cancellationToken);

        return new ChatInferenceResultDto
        {
            ResponseText = response.ResponseText,
            TokensUsed = response.TokensUsed,
            IsViolation = response.IsViolation,
            ViolationKeywords = [.. response.ViolationKeywords],
            DataVerified = response.DataVerified,
            Citations = response.Citations.Select(c => new CitationResultDto
            {
                DocumentTitle = c.DocumentTitle,
                ArticleNumber = c.ArticleNumber,
                ClauseNumber = c.ClauseNumber,
                SourceUrl = c.SourceUrl,
                Excerpt = c.Excerpt
            }).ToList()
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phúc: Document Verification (Crawler & Cron Job)
    // ─────────────────────────────────────────────────────────────────────────

    public async Task<VerificationResultDto> VerifyLegalDocumentAsync(
        string documentTitle,
        string documentNumber,
        string content = "",
        CancellationToken cancellationToken = default)
    {
        logger.LogInformation(
            "Calling gRPC VerifyLegalDocument: Title='{Title}', Number='{Number}'",
            documentTitle, documentNumber);

        var request = new VerificationRequest
        {
            DocumentTitle = documentTitle,
            DocumentNumber = documentNumber,
            Content = content
        };

        var response = await grpcClient.VerifyLegalDocumentAsync(
            request, cancellationToken: cancellationToken);

        return new VerificationResultDto
        {
            IsValid = response.IsValid,
            Status = response.Status,
            Notes = response.Notes
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Phúc: Document Indexing (Crawler cào xong → đẩy vào Qdrant)
    // ─────────────────────────────────────────────────────────────────────────

    public async Task<IndexDocumentResultDto> IndexDocumentAsync(
        IEnumerable<DocumentChunkInputDto> chunks,
        CancellationToken cancellationToken = default)
    {
        var chunkList = chunks.ToList();
        logger.LogInformation(
            "Calling gRPC IndexDocument with {Count} chunks", chunkList.Count);

        var request = new IndexDocumentRequest();
        request.Chunks.AddRange(chunkList.Select(c => new DocumentChunkItem
        {
            ChunkId = c.ChunkId,
            DocumentTitle = c.DocumentTitle,
            DocumentNumber = c.DocumentNumber,
            Chapter = c.Chapter,
            Article = c.Article,
            Clause = c.Clause,
            Content = c.Content,
            SourceUrl = c.SourceUrl,
            IsVerified = c.IsVerified,
            IsActive = c.IsActive
        }));

        var response = await grpcClient.IndexDocumentAsync(
            request, cancellationToken: cancellationToken);

        return new IndexDocumentResultDto
        {
            Success = response.Success,
            IndexedCount = response.IndexedCount,
            Message = response.Message
        };
    }
}

