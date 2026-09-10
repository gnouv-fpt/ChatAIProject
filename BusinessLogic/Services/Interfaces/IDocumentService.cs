using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

public interface IDocumentService
{
    Task<DocumentUploadResult> UploadAndIndexAsync(
        DocumentUploadRequest request,
        CancellationToken cancellationToken = default);

    Task<DocumentBatchUploadResult> UploadBatchAndIndexAsync(
        DocumentBatchUploadRequest request,
        CancellationToken cancellationToken = default);

    Task<DocumentListResultDto> GetDocumentsAsync(
        DocumentListRequestDto request,
        CancellationToken cancellationToken = default);

    Task<DocumentDetailDto?> GetDocumentDetailAsync(
        int documentId,
        CancellationToken cancellationToken = default);

    Task<DocumentChunksDto?> GetDocumentChunksAsync(
        int documentId,
        int page,
        int pageSize,
        int currentUserId,
        string? currentUserRole,
        CancellationToken cancellationToken = default);

    Task<DocumentUploadResult> VerifyAndIndexAsync(
        int documentId,
        int verifiedBy,
        string? verifierRole,
        CancellationToken cancellationToken = default);

    Task<DocumentUploadResult> RejectAsync(
        int documentId,
        int rejectedBy,
        string? rejecterRole,
        string? reason,
        CancellationToken cancellationToken = default);

    Task<DocumentUploadResult> DeleteAsync(
        int documentId,
        int deletedBy,
        string? deleterRole,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SubjectOptionDto>> GetSubjectOptionsAsync(
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SubjectOptionDto>> GetUploadSubjectOptionsAsync(
        int userId,
        string? userRole,
        CancellationToken cancellationToken = default);

    /// <summary>Returns (filePath, originalFileName) for download, or null if not found / unauthorized.</summary>
    Task<(string FilePath, string OriginalFileName)?> GetDocumentFileAsync(
        int documentId,
        int requestingUserId,
        string? requestingUserRole,
        CancellationToken cancellationToken = default);
}
