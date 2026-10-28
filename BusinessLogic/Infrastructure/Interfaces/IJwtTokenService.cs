using BusinessObject.Entities;

namespace BusinessLogic.Infrastructure.Interfaces;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAt) CreateAccessToken(User user);

    (string Token, DateTime ExpiresAt) CreateRefreshToken(User user);

    /// <summary>
    /// Validates a refresh token (signature, issuer, refresh audience, lifetime)
    /// and returns its claims, or null when it is invalid.
    /// </summary>
    Task<RefreshTokenClaims?> ValidateRefreshTokenAsync(string refreshToken);

    /// <summary>
    /// Stamp derived from the password hash: changing the password invalidates
    /// every refresh token issued before, without a token table.
    /// </summary>
    string ComputeSecurityStamp(User user);
}

public sealed record RefreshTokenClaims(Guid UserId, string SecurityStamp);
