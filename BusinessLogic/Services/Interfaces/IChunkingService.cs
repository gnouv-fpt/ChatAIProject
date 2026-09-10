using BusinessLogic.Infrastructure;
using BusinessLogic.Infrastructure.Interfaces;

namespace BusinessLogic.Services.Interfaces;

public interface IChunkingService
{
    Task<IReadOnlyList<DocumentChunkDraft>> SplitIntoChunksAsync(
        IReadOnlyList<ExtractedTextSegment> segments,
        CancellationToken cancellationToken = default);
}

public sealed record DocumentChunkDraft(
    int ChunkIndex,
    string Content,
    int? PageNumber,
    int? SlideNumber,
    int TokenCount);
