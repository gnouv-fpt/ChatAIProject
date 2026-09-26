namespace BusinessLogic.DTOs;

public class CitationResultDto
{
    public string DocumentTitle { get; set; } = string.Empty;
    public string ArticleNumber { get; set; } = string.Empty;
    public string ClauseNumber { get; set; } = string.Empty;
    public string SourceUrl { get; set; } = string.Empty;
    public string Excerpt { get; set; } = string.Empty;
}

public class ChatInferenceResultDto
{
    public string ResponseText { get; set; } = string.Empty;
    public int TokensUsed { get; set; }
    public bool IsViolation { get; set; }
    public List<string> ViolationKeywords { get; set; } = new();
    public List<CitationResultDto> Citations { get; set; } = new();
    public bool DataVerified { get; set; }
}

public class VerificationResultDto
{
    public bool IsValid { get; set; }
    public string Status { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
}

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

public class IndexDocumentResultDto
{
    public bool Success { get; set; }
    public int IndexedCount { get; set; }
    public string Message { get; set; } = string.Empty;
}
