namespace BusinessLogic.DTOs;

/// <summary>
/// Kết quả suy diễn từ gRPC Inference Service (ProcessChatMessage).
/// Đây là DTO trung gian giữa generated Protobuf class và tầng Service/Controller.
/// </summary>
public class ChatInferenceResultDto
{
    public string ResponseText { get; set; } = string.Empty;
    public int TokensUsed { get; set; }
    public bool IsViolation { get; set; }
    public List<string> ViolationKeywords { get; set; } = [];
    public List<CitationResultDto> Citations { get; set; } = [];
    public bool DataVerified { get; set; }
}

/// <summary>
/// Trích dẫn pháp lý được trích xuất từ Qdrant RAG (Điều, Khoản, Nguồn).
/// </summary>
public class CitationResultDto
{
    public string DocumentTitle { get; set; } = string.Empty;
    public string ArticleNumber { get; set; } = string.Empty;
    public string ClauseNumber { get; set; } = string.Empty;
    public string SourceUrl { get; set; } = string.Empty;
    public string Excerpt { get; set; } = string.Empty;
}

// ─────────────────────────────────────────────────────────────────────────────
// DTOs cho Phúc: Document Verification & Indexing (crawler + cron jobs)
// ─────────────────────────────────────────────────────────────────────────────

/// <summary>
/// Kết quả xác minh tính pháp lý của một văn bản luật (VerifyLegalDocument RPC).
/// Phúc dùng trong cron job cào tài liệu từ thuvienphapluat.vn.
/// </summary>
public class VerificationResultDto
{
    /// <summary>true nếu văn bản còn hiệu lực, false nếu đã hết hiệu lực hoặc chưa xác định.</summary>
    public bool IsValid { get; set; }
    /// <summary>"Verified" | "Outdated" | "Pending"</summary>
    public string Status { get; set; } = string.Empty;
    /// <summary>Ghi chú bổ sung (văn bản sửa đổi, ngày hết hiệu lực, v.v.).</summary>
    public string Notes { get; set; } = string.Empty;
}

/// <summary>
/// Một đoạn văn bản pháp lý (chunk) cần đẩy vào Vector DB (IndexDocument RPC).
/// Map 1-1 với DocumentChunkItem trong proto.
/// </summary>
public class DocumentChunkInputDto
{
    public string ChunkId { get; set; } = string.Empty;
    public string DocumentTitle { get; set; } = string.Empty;
    public string DocumentNumber { get; set; } = string.Empty;
    public string Chapter { get; set; } = string.Empty;
    public string Article { get; set; } = string.Empty;
    public string Clause { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string SourceUrl { get; set; } = string.Empty;
    public bool IsVerified { get; set; } = true;
    public bool IsActive { get; set; } = true;
}

/// <summary>
/// Kết quả sau khi index batch chunks vào Qdrant (IndexDocument RPC).
/// </summary>
public class IndexDocumentResultDto
{
    public bool Success { get; set; }
    public int IndexedCount { get; set; }
    public string Message { get; set; } = string.Empty;
}

