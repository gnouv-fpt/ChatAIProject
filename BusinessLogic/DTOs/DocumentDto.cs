namespace BusinessLogic.DTOs;

using BusinessObject.Enums;

public class DocumentDto
{
    public Guid Id { get; set; }
    public string DocumentNumber { get; set; } = null!;
    public string Title { get; set; } = null!;
    public LegalDocumentType DocumentType { get; set; }
    public string? IssuingAuthority { get; set; }
    public DateTime? EffectiveDate { get; set; }
    public DateTime? ExpirationDate { get; set; }
    public bool IsActive { get; set; }
    public VerificationStatus VerificationStatus { get; set; }
    public DateTime? LastVerifiedAt { get; set; }
    public string? SourceUrl { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class DocumentFilterDto
{
    public string? Keyword { get; set; }
    public bool? IsActive { get; set; }
    public int PageIndex { get; set; } = 1;
    public int PageSize { get; set; } = 10;
}

public class PagedResult<T>
{
    public List<T> Items { get; set; } = new();
    public int TotalCount { get; set; }
    public int PageIndex { get; set; }
    public int PageSize { get; set; }
}