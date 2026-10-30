using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class DocumentIndexService(IDocumentRepository documents, IGenericRepository<DocumentChunk> chunks,
    IGrpcInferenceService inference, ILogger<DocumentIndexService> logger, ContentPipelineSettings settings) : IDocumentIndexService
{
    public async Task<IndexDocumentResultDto> VerifyAndIndexAsync(Guid id, VerifyDocumentRequestDto request, CancellationToken cancellationToken = default)
    {
        if (!settings.EnableVerifiedIndexing)
            throw new AppException(503, "Lập chỉ mục đang chờ tích hợp version/deactivate và kiểm tra hiệu lực SQL trong luồng chat.");
        var document = await documents.GetByIdAsync(id, cancellationToken) ?? throw new NotFoundException("Không tìm thấy văn bản.");
        var now = DateTime.UtcNow;
        if (!Uri.TryCreate(request.EvidenceUrl, UriKind.Absolute, out var evidence) || !LegalContentParser.IsAllowedSource(evidence) ||
            request.EvidenceUrl != document.SourceUrl || !request.SourceAndAmendmentsReviewed ||
            request.EffectiveDate.Kind != DateTimeKind.Utc || request.EffectiveDate == default || request.EffectiveDate > now ||
            (request.ExpirationDate.HasValue && (request.ExpirationDate.Value.Kind != DateTimeKind.Utc ||
                request.ExpirationDate <= now || request.ExpirationDate <= request.EffectiveDate)) || string.IsNullOrWhiteSpace(request.ReviewNotes))
            throw new BadRequestException("Cần nguồn gốc khớp văn bản, xác nhận sửa đổi và ngày hiệu lực UTC còn hiệu lực.");
        var content = await chunks.FindAsync(c => c.DocumentId == id, cancellationToken);
        if (content.Count == 0) throw new BadRequestException("Văn bản chưa có toàn văn/chunks.");
        // Reindexing an active document requires the version/deactivate contract from K04.
        if (document.IsActive) throw new ConflictException("Văn bản đang hoạt động; cần contract version/deactivate để tái lập chỉ mục an toàn.");
        var verification = await inference.VerifyLegalDocumentAsync(document.Title, document.DocumentNumber,
            string.Join("\n", content.Select(c => c.Content)), cancellationToken);
        cancellationToken.ThrowIfCancellationRequested();
        if (!verification.IsValid || verification.Status != nameof(VerificationStatus.Verified))
            throw new ConflictException("Dịch vụ chưa xác minh được hiệu lực văn bản. Giữ trạng thái chờ kiểm tra.");
        var result = await inference.IndexDocumentAsync(content.Select(c => new DocumentChunkInputDto {
            ChunkId = c.Id.ToString(), DocumentTitle = document.Title, DocumentNumber = document.DocumentNumber,
            Article = c.Article ?? "", Clause = c.Clause ?? "", Chapter = c.Chapter ?? "", Content = c.Content,
            SourceUrl = document.SourceUrl!, IsVerified = true, IsActive = true }), cancellationToken);
        cancellationToken.ThrowIfCancellationRequested();
        if (!result.Success || result.IndexedCount != content.Count)
            throw new AppException(503, "Chưa lập chỉ mục đủ chunks. Văn bản chưa được kích hoạt; có thể thử lại với cùng ID.");
        document.IsActive = true;
        document.VerificationStatus = VerificationStatus.Verified;
        document.LastVerifiedAt = now;
        document.EffectiveDate = request.EffectiveDate;
        document.ExpirationDate = request.ExpirationDate;
        foreach (var chunk in content) { chunk.IsVerified = true; chunk.VectorId = chunk.Id.ToString(); chunks.Update(chunk); }
        await documents.SaveChangesAsync(cancellationToken);
        logger.LogInformation("Document {DocumentId} reviewed and indexed: {ChunkCount} chunks, evidence {EvidenceUrl}", id, content.Count, request.EvidenceUrl);
        return result;
    }
}
