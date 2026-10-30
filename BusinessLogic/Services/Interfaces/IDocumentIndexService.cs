using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

public interface IDocumentIndexService
{
    Task<IndexDocumentResultDto> VerifyAndIndexAsync(Guid id, VerifyDocumentRequestDto request, CancellationToken cancellationToken = default);
}
