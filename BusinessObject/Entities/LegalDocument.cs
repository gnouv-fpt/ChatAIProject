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

    // Incremented whenever verified content changes; citations and index jobs carry it.
    public int Version { get; set; } = 1;

    public string? ContentHash { get; set; }

    // Pending document-updated-events outbox entry, written in the same transaction as the change.
    public string? EventPayload { get; set; }

    public DateTime? EventPublishedAt { get; set; }

    public ICollection<DocumentChunk> Chunks { get; set; } = new List<DocumentChunk>();
}
