using BusinessObject.Entities;

namespace BusinessLogic.Services.Interfaces;

public interface IContentCatalogClient
{
    Task<List<DocumentChunk>> GetChunksAsync(Guid[] ids, CancellationToken cancellationToken);
}
