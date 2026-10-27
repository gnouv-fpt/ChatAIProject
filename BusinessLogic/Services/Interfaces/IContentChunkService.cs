using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

public interface IContentChunkService
{
    Task<IReadOnlyList<ContentChunkSnapshotDto>> GetAsync(Guid[] ids, CancellationToken cancellationToken);
}
