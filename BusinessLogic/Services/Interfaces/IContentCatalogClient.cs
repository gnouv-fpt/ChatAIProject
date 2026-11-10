using BusinessObject.Entities;
using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

public interface IContentCatalogClient
{
    Task<List<DocumentChunk>> GetChunksAsync(Guid[] ids, CancellationToken cancellationToken);
    Task<ScenarioAnswerDto?> ResolveScenarioAsync(int? number, IReadOnlyList<string> imageHashes,
        CancellationToken cancellationToken);
}
