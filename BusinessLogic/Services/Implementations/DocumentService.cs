using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class DocumentService : IDocumentService
{
    private readonly IDocumentRepository _documentRepository;

    public DocumentService(IDocumentRepository documentRepository)
    {
        _documentRepository = documentRepository;
    }

    public async Task<PagedResult<DocumentDto>> GetDocumentsAsync(
        DocumentFilterDto filter,
        CancellationToken cancellationToken = default)
    {
        var pageIndex = Math.Max(filter.PageIndex, 1);
        var pageSize = Math.Clamp(filter.PageSize, 1, 100);
        var page = await _documentRepository.GetDocumentsAsync(
            filter.Keyword,
            filter.IsActive,
            pageIndex,
            pageSize,
            cancellationToken);

        return new PagedResult<DocumentDto>
        {
            Items = page.Items.Select(Map).ToList(),
            TotalCount = page.TotalCount,
            PageIndex = pageIndex,
            PageSize = pageSize
        };
    }

    public async Task<DocumentDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var document = await _documentRepository.GetByIdAsync(id, cancellationToken);
        return document is null ? null : Map(document);
    }

    private static DocumentDto Map(BusinessObject.Entities.LegalDocument document) => new()
    {
        Id = document.Id,
        DocumentNumber = document.DocumentNumber,
        Title = document.Title,
        DocumentType = document.DocumentType,
        IssuingAuthority = document.IssuingAuthority,
        EffectiveDate = document.EffectiveDate,
        ExpirationDate = document.ExpirationDate,
        IsActive = document.IsActive,
        VerificationStatus = document.VerificationStatus,
        LastVerifiedAt = document.LastVerifiedAt,
        SourceUrl = document.SourceUrl,
        CreatedAt = document.CreatedAt
    };
}