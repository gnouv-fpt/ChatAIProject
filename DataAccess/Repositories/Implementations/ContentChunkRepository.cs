using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class ContentChunkRepository(ContentDbContext db) : IContentChunkRepository
{
    public Task<List<DocumentChunk>> GetAsync(Guid[] ids, CancellationToken ct) =>
        db.DocumentChunks.AsNoTracking().Include(c => c.Document).Where(c => ids.Contains(c.Id)).ToListAsync(ct);
}
