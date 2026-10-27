using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class ContentChunkService(IContentChunkRepository repository) : IContentChunkService
{
    public async Task<IReadOnlyList<ContentChunkSnapshotDto>> GetAsync(Guid[] ids, CancellationToken ct)
    {
        if (ids is null || ids.Length > 50 || ids.Any(id => id == Guid.Empty))
            throw new BadRequestException("Danh sách đoạn văn bản không hợp lệ (tối đa 50).");
        var chunks = await repository.GetAsync(ids.Distinct().ToArray(), ct);
        return chunks.Select(c => new ContentChunkSnapshotDto(c.Id, c.DocumentId, c.Content, c.Article,
            c.Clause, c.Point, c.IsVerified, c.Document.Title, c.Document.SourceUrl, c.Document.IsActive,
            c.Document.VerificationStatus, c.Document.EffectiveDate, c.Document.ExpirationDate, c.Document.Version)).ToArray();
    }
}
