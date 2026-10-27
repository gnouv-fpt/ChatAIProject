using BusinessObject.Entities;

namespace BusinessLogic.Infrastructure.Interfaces;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAt) CreateAccessToken(User user);

    (string Token, DateTime ExpiresAt) CreateRefreshToken(User user);
    Task<(Guid UserId, DateTime ExpiresAt)?> ValidateRefreshTokenAsync(string token);
    string CreateContentServiceToken();
}
