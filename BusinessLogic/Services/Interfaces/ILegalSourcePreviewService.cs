using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

public interface ILegalSourcePreviewService
{
    Task<LegalSourceEvidenceDto> PreviewAsync(string sourceUrl, CancellationToken cancellationToken = default);
}
