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
    ILogger<GrpcInferenceService> logger,
    BusinessLogic.Infrastructure.Settings.ChatSettings settings) : IGrpcInferenceService
{
    public Task<ChatInferenceResultDto> ProcessChatMessageAsync(string userId, string sessionId,
        string prompt, CancellationToken cancellationToken = default) =>
        ProcessTurnAsync(new(Guid.Parse(userId), Guid.Parse(sessionId), Guid.NewGuid(), prompt, [], [], 4096), cancellationToken);

    public async Task<ChatInferenceResultDto> ProcessTurnAsync(ChatInferenceInputDto input, CancellationToken cancellationToken = default)
    {
        var request = new ChatInferenceRequest
        {
            UserId = input.UserId.ToString(), SessionId = input.SessionId.ToString(),
            RequestId = input.RequestId.ToString(), Prompt = input.Prompt, MaxTokens = input.MaxTokens
        };
        request.Images.AddRange(input.Images.Select(i => new ChatImage
        {
            AttachmentId = i.AttachmentId.ToString(), MimeType = i.MimeType,
            Content = Google.Protobuf.ByteString.CopyFrom(i.Content)
        }));
        request.History.AddRange(input.History.Select(h => new HistoryItem { Role = h.Role, Content = h.Content }));
        var headers = new Metadata();
        if (System.Diagnostics.Activity.Current?.Id is { } trace) headers.Add("traceparent", trace);
        try
        {
            var response = await grpcClient.ProcessChatMessageAsync(request, headers,
                deadline: DateTime.UtcNow.AddSeconds(settings.InferenceTimeoutSeconds), cancellationToken: cancellationToken);
            if (response.ContractVersion < 2)
                throw new BusinessLogic.Exceptions.ServiceUnavailableException("AI service chưa hỗ trợ hợp đồng chat v2. Vui lòng thử lại sau khi cập nhật dịch vụ.");
            if (!response.HasTokensUsed)
                throw new BusinessLogic.Exceptions.ServiceUnavailableException("Dịch vụ AI chưa cung cấp thông tin usage. Vui lòng thử lại sau khi đối soát.");
            if (input.Images.Count > 0 && !response.ImagesProcessed)
                throw new BusinessLogic.Exceptions.ServiceUnavailableException("AI service chưa xử lý được ảnh đính kèm.");
            return new ChatInferenceResultDto
            {
                ContractVersion = response.ContractVersion, ImagesProcessed = response.ImagesProcessed,
                Status = response.ResultStatus, ResponseText = response.ResponseText,
                TokensUsed = response.TokensUsed, IsViolation = response.IsViolation,
                ViolationKeywords = [.. response.ViolationKeywords], DataVerified = response.DataVerified,
                Citations = response.Citations.Select(c => new CitationResultDto
                {
                    ChunkId = c.ChunkId, ContentHash = c.ContentHash, PointNumber = c.PointNumber,
                    DocumentTitle = c.DocumentTitle, ArticleNumber = c.ArticleNumber,
                    ClauseNumber = c.ClauseNumber, SourceUrl = c.SourceUrl, Excerpt = c.Excerpt
                }).ToList()
            };
        }
        catch (RpcException) when (cancellationToken.IsCancellationRequested)
        {
            throw new OperationCanceledException(cancellationToken);
        }
        catch (RpcException ex)
        {
            logger.LogWarning("Chat RPC failed: {Status}", ex.StatusCode);
            if (ex.StatusCode == StatusCode.DeadlineExceeded)
                throw new BusinessLogic.Exceptions.UpstreamTimeoutException("Dịch vụ AI phản hồi quá chậm. Vui lòng thử lại.");
            throw new BusinessLogic.Exceptions.ServiceUnavailableException("Dịch vụ AI tạm thời không khả dụng. Vui lòng thử lại.");
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
                request, deadline: DateTime.UtcNow.AddSeconds(settings.InferenceTimeoutSeconds), cancellationToken: cancellationToken);

            return new VerificationResultDto
            {
                IsValid = response.IsValid,
                Status = response.Status,
                Notes = response.Notes
            };
        }
        catch (RpcException) when (cancellationToken.IsCancellationRequested)
        {
            throw new OperationCanceledException(cancellationToken);
        }
        catch (RpcException ex)
        {
            logger.LogWarning("Verification RPC failed: {Status}", ex.StatusCode);
            throw new BusinessLogic.Exceptions.ServiceUnavailableException("Dịch vụ xác thực văn bản tạm thời không khả dụng.");
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
            Point = c.Point, ContentHash = c.ContentHash, DocumentId = c.DocumentId,
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
                request, deadline: DateTime.UtcNow.AddSeconds(settings.InferenceTimeoutSeconds), cancellationToken: cancellationToken);

            return new IndexDocumentResultDto
            {
                Success = response.Success,
                IndexedCount = response.IndexedCount,
                Message = response.Message
            };
        }
        catch (RpcException) when (cancellationToken.IsCancellationRequested)
        {
            throw new OperationCanceledException(cancellationToken);
        }
        catch (RpcException ex)
        {
            logger.LogWarning("Index RPC failed: {Status}", ex.StatusCode);
            throw new BusinessLogic.Exceptions.ServiceUnavailableException("Dịch vụ lập chỉ mục tạm thời không khả dụng.");
        }
    }
}
