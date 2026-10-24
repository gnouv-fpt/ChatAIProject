namespace BusinessLogic.DTOs;

public class CitationResultDto
{
    public string ChunkId { get; set; } = string.Empty;
    public string ContentHash { get; set; } = string.Empty;
    public string PointNumber { get; set; } = string.Empty;
    public string DocumentTitle { get; set; } = string.Empty;
    public string ArticleNumber { get; set; } = string.Empty;
    public string ClauseNumber { get; set; } = string.Empty;
    public string SourceUrl { get; set; } = string.Empty;
    public string Excerpt { get; set; } = string.Empty;
}

public class ChatInferenceResultDto
{
    public string Status { get; set; } = string.Empty;
    public int ContractVersion { get; set; }
    public bool ImagesProcessed { get; set; }
    public string ResponseText { get; set; } = string.Empty;
    public int TokensUsed { get; set; }
    public bool IsViolation { get; set; }
    public List<string> ViolationKeywords { get; set; } = new();
    public List<CitationResultDto> Citations { get; set; } = new();
    public bool DataVerified { get; set; }
}

public sealed record ChatImageDto(Guid AttachmentId, string MimeType, byte[] Content);
public sealed record ChatHistoryDto(string Role, string Content);
public sealed record ChatInferenceInputDto(Guid UserId, Guid SessionId, Guid RequestId, string Prompt,
    IReadOnlyList<ChatImageDto> Images, IReadOnlyList<ChatHistoryDto> History, int MaxTokens);

public class VerificationResultDto
{
    public bool IsValid { get; set; }
    public string Status { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
}

public class DocumentChunkInputDto
{
    public string Point { get; set; } = string.Empty;
    public string ContentHash { get; set; } = string.Empty;
    public string DocumentId { get; set; } = string.Empty;
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

public class IndexDocumentResultDto
{
    public bool Success { get; set; }
    public int IndexedCount { get; set; }
    public string Message { get; set; } = string.Empty;
}
