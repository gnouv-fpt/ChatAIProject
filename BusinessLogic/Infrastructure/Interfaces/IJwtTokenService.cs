using BusinessObject.Entities;

namespace BusinessLogic.Infrastructure.Interfaces;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAt) CreateAccessToken(User user);

    (string Token, DateTime ExpiresAt) CreateRefreshToken(User user);
    Task<RefreshTokenClaims?> ValidateRefreshTokenAsync(string token);
    string ComputeSecurityStamp(User user);
    string CreateContentServiceToken();
    string CreateExamServiceToken();
    string CreateContentMaintenanceToken();
}

public sealed record RefreshTokenClaims(Guid UserId, DateTime ExpiresAt, string SecurityStamp);
