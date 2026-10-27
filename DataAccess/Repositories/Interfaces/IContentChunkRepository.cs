using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IContentChunkRepository
{
    Task<List<DocumentChunk>> GetAsync(Guid[] ids, CancellationToken cancellationToken);
}
