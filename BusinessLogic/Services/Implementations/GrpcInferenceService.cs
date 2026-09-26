using BusinessLogic.DTOs;
using BusinessLogic.Protos;
using BusinessLogic.Services.Interfaces;
using Grpc.Core;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

/// <summary>
/// Gọi gRPC Inference Service qua Grpc.Net.Client.
/// Đây là lớp duy nhất trong .NET biết về generated Protobuf types.
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

        try
        {
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
        catch (RpcException ex)
        {
            logger.LogError(ex, "gRPC ProcessChatMessage failed with status {StatusCode}: {Detail}", ex.StatusCode, ex.Status.Detail);
            
            // Graceful fallback for chat assistant
            return new ChatInferenceResultDto
            {
                ResponseText = "Hệ thống AI tư vấn pháp luật giao thông hiện tại đang bận hoặc tạm thời mất kết nối tới AI Inference Service. Vui lòng kiểm tra lại kết nối hoặc thử lại sau.",
                TokensUsed = 0,
                IsViolation = false,
                DataVerified = false,
                Citations = new List<CitationResultDto>()
            };
        }
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

        try
        {
            var response = await grpcClient.VerifyLegalDocumentAsync(
                request, cancellationToken: cancellationToken);

            return new VerificationResultDto
            {
                IsValid = response.IsValid,
                Status = response.Status,
                Notes = response.Notes
            };
        }
        catch (RpcException ex)
        {
            logger.LogError(ex, "gRPC VerifyLegalDocument failed: {Detail}", ex.Status.Detail);
            return new VerificationResultDto
            {
                IsValid = false,
                Status = "Pending",
                Notes = $"Không thể kết nối tới verification service: {ex.Status.Detail}"
            };
        }
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

        try
        {
            var response = await grpcClient.IndexDocumentAsync(
                request, cancellationToken: cancellationToken);

            return new IndexDocumentResultDto
            {
                Success = response.Success,
                IndexedCount = response.IndexedCount,
                Message = response.Message
            };
        }
        catch (RpcException ex)
        {
            logger.LogError(ex, "gRPC IndexDocument failed: {Detail}", ex.Status.Detail);
            return new IndexDocumentResultDto
            {
                Success = false,
                IndexedCount = 0,
                Message = $"Lỗi kết nối gRPC index: {ex.Status.Detail}"
            };
        }
    }
}
