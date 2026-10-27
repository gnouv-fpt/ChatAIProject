using BusinessObject.Entities;
using BusinessObject.Enums;

namespace BusinessLogic.DTOs;

public sealed record ContentChunkSnapshotDto(Guid Id, Guid DocumentId, string Content, string? Article,
    string? Clause, string? Point, bool IsVerified, string DocumentTitle, string? SourceUrl,
    bool IsActive, VerificationStatus VerificationStatus, DateTime? EffectiveDate, DateTime? ExpirationDate,
    int DocumentVersion = 1)
{
    public DocumentChunk ToEntity() => new()
    {
        Id = Id, DocumentId = DocumentId, Content = Content, Article = Article, Clause = Clause,
        Point = Point, IsVerified = IsVerified,
        Document = new LegalDocument
        {
            Id = DocumentId, Title = DocumentTitle, SourceUrl = SourceUrl, IsActive = IsActive,
            VerificationStatus = VerificationStatus, EffectiveDate = EffectiveDate, ExpirationDate = ExpirationDate,
            Version = DocumentVersion
        }
    };
}
