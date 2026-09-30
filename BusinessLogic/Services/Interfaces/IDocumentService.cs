using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

public interface IDocumentService
{
    Task<PagedResult<DocumentDto>> GetDocumentsAsync(
        DocumentFilterDto filter,
        CancellationToken cancellationToken = default);

    Task<DocumentDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
}