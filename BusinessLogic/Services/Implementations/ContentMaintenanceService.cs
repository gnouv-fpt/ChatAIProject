using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class ContentMaintenanceService(IDocumentRepository documents,
    IGenericRepository<DocumentChunk> chunks, ILogger<ContentMaintenanceService> logger,
    IGrpcInferenceService? inference = null) : IContentMaintenanceService
{
    public async Task<ContentMaintenanceResult> RunAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var expired = await documents.FindAsync(d => d.ExpirationDate != null && d.ExpirationDate <= now, cancellationToken);
        var count = 0;
        var changedDocuments = expired.Count(d => d.IsActive || d.VerificationStatus != VerificationStatus.Outdated);
        foreach (var document in expired)
        {
            document.IsActive = false;
            document.VerificationStatus = VerificationStatus.Outdated;
            documents.Update(document);
            foreach (var chunk in await chunks.FindAsync(c => c.DocumentId == document.Id && c.IsVerified, cancellationToken))
            {
                chunk.IsVerified = false;
                chunks.Update(chunk);
                count++;
            }
        }
        await documents.SaveChangesAsync(cancellationToken);
        // SQL eligibility is revoked first. Repeating the expired set repairs a failed vector RPC on the next run.
        if (inference is not null)
            foreach (var document in expired)
                await inference.DeactivateDocumentAsync(document.DocumentNumber, cancellationToken);
        logger.LogInformation("Content expiry: {Documents} documents, {Chunks} chunks invalidated in SQL", expired.Count, count);
        return new(changedDocuments, count);
    }
}
