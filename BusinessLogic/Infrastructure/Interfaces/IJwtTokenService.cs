using BusinessObject.Entities;

namespace BusinessLogic.Infrastructure.Interfaces;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAt) CreateAccessToken(User user);

    string GenerateRefreshToken();

    string HashRefreshToken(string refreshToken);
}
