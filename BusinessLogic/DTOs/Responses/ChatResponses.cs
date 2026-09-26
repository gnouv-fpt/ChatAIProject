using BusinessObject.Enums;

namespace BusinessLogic.DTOs.Responses;

public class CitationResponseDto
{
    public Guid Id { get; set; }

    public string? DocumentTitle { get; set; }

    public string? ArticleNumber { get; set; }

    public string? ClauseNumber { get; set; }

    public string? Excerpt { get; set; }

    public string? SourceUrl { get; set; }
}

public class ChatMessageResponseDto
{
    public Guid Id { get; set; }

    public Guid SessionId { get; set; }

    public SenderRole SenderRole { get; set; }

    public string Content { get; set; } = string.Empty;

    public int TokensUsed { get; set; }

    public bool IsViolation { get; set; }

    public DateTime CreatedAt { get; set; }

    public List<CitationResponseDto> Citations { get; set; } = new();
}

public class ChatSessionResponseDto
{
    public Guid Id { get; set; }

    public string Title { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public DateTime LastUpdatedAt { get; set; }

    public int MessageCount { get; set; }
}

public class ChatSessionDetailResponseDto
{
    public Guid Id { get; set; }

    public string Title { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; }

    public DateTime LastUpdatedAt { get; set; }

    public List<ChatMessageResponseDto> Messages { get; set; } = new();
}

public class PagedResultDto<T>
{
    public IReadOnlyList<T> Items { get; set; } = Array.Empty<T>();

    public int TotalCount { get; set; }

    public int PageIndex { get; set; }

    public int PageSize { get; set; }

    public int TotalPages => PageSize > 0 ? (int)Math.Ceiling((double)TotalCount / PageSize) : 0;
}
