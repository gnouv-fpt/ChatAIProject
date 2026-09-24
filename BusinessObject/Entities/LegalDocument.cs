using BusinessObject.Enums;

namespace BusinessObject.Entities;

public class LegalDocument
{
    public Guid Id { get; set; }

    public string DocumentNumber { get; set; } = null!;

    public string Title { get; set; } = null!;

    public LegalDocumentType DocumentType { get; set; } = LegalDocumentType.Other;

    public string? IssuingAuthority { get; set; }

    public DateTime? EffectiveDate { get; set; }

    public DateTime? ExpirationDate { get; set; }

    public bool IsActive { get; set; }

    public VerificationStatus VerificationStatus { get; set; } = VerificationStatus.Pending;

    public DateTime? LastVerifiedAt { get; set; }

    public string? SourceUrl { get; set; }

    public DateTime CreatedAt { get; set; }

    public ICollection<DocumentChunk> Chunks { get; set; } = new List<DocumentChunk>();
}
