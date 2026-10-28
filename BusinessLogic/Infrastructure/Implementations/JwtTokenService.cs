using System.Security.Cryptography;
using System.Text;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using BusinessObject.Entities;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace BusinessLogic.Infrastructure.Implementations;

public sealed class JwtTokenService : IJwtTokenService
{
    private readonly JwtSettings _settings;
    private readonly SigningCredentials _signingCredentials;
    private readonly TokenValidationParameters _refreshValidationParameters;
    private readonly JsonWebTokenHandler _tokenHandler = new();

    public JwtTokenService(JwtSettings settings)
    {
        _settings = settings;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SecretKey));
        _signingCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        // Refresh tokens use their own audience, so the JwtBearer middleware (which only
        // accepts settings.Audience) never accepts them as access tokens, and vice versa.
        _refreshValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = settings.Issuer,
            ValidateAudience = true,
            ValidAudience = settings.RefreshAudience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = key,
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    }

    public (string Token, DateTime ExpiresAt) CreateAccessToken(User user)
    {
        var now = DateTime.UtcNow;
        var expiresAt = now.AddMinutes(_settings.AccessTokenMinutes);

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _settings.Issuer,
            Audience = _settings.Audience,
            IssuedAt = now,
            NotBefore = now,
            Expires = expiresAt,
            SigningCredentials = _signingCredentials,
            Claims = new Dictionary<string, object>
            {
                [AppClaimTypes.UserId] = user.Id.ToString(),
                [AppClaimTypes.Username] = user.Username,
                [AppClaimTypes.Email] = user.Email,
                [AppClaimTypes.Role] = user.Role.ToString(),
                [AppClaimTypes.TokenQuota] = user.TokenQuota,
                [JwtRegisteredClaimNames.Jti] = Guid.NewGuid().ToString()
            }
        };

        return (_tokenHandler.CreateToken(descriptor), expiresAt);
    }

    public (string Token, DateTime ExpiresAt) CreateRefreshToken(User user)
    {
        var now = DateTime.UtcNow;
        var expiresAt = now.AddDays(_settings.RefreshTokenDays);

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _settings.Issuer,
            Audience = _settings.RefreshAudience,
            IssuedAt = now,
            NotBefore = now,
            Expires = expiresAt,
            SigningCredentials = _signingCredentials,
            Claims = new Dictionary<string, object>
            {
                [AppClaimTypes.UserId] = user.Id.ToString(),
                [AppClaimTypes.SecurityStamp] = ComputeSecurityStamp(user),
                [JwtRegisteredClaimNames.Jti] = Guid.NewGuid().ToString()
            }
        };

        return (_tokenHandler.CreateToken(descriptor), expiresAt);
    }

    public async Task<RefreshTokenClaims?> ValidateRefreshTokenAsync(string refreshToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return null;
        }

        var result = await _tokenHandler.ValidateTokenAsync(refreshToken, _refreshValidationParameters);
        if (!result.IsValid
            || !result.Claims.TryGetValue(AppClaimTypes.UserId, out var sub)
            || !Guid.TryParse(sub?.ToString(), out var userId)
            || !result.Claims.TryGetValue(AppClaimTypes.SecurityStamp, out var stamp)
            || stamp?.ToString() is not { Length: > 0 } securityStamp)
        {
            return null;
        }

        return new RefreshTokenClaims(userId, securityStamp);
    }

    public string ComputeSecurityStamp(User user)
    {
        // Keyed with the signing secret so the stamp leaks nothing usable about the password hash.
        var hash = HMACSHA256.HashData(
            Encoding.UTF8.GetBytes(_settings.SecretKey),
            Encoding.UTF8.GetBytes(user.PasswordHash));
        return Convert.ToHexString(hash, 0, 16);
    }
}
