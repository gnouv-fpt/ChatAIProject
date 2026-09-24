using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class RefreshTokenRepository : GenericRepository<RefreshToken>, IRefreshTokenRepository
{
    public RefreshTokenRepository(ChatAIWebDbContext context)
        : base(context)
    {
    }

    public Task<RefreshToken?> GetByTokenHashWithUserAsync(
        string tokenHash,
        CancellationToken cancellationToken = default)
    {
        return DbSet
            .Include(t => t.User)
            .FirstOrDefaultAsync(t => t.TokenHash == tokenHash, cancellationToken);
    }
}
