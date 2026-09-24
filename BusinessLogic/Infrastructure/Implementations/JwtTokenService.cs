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
    private readonly JsonWebTokenHandler _tokenHandler = new();

    public JwtTokenService(JwtSettings settings)
    {
        _settings = settings;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SecretKey));
        _signingCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
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

    public string GenerateRefreshToken()
    {
        return Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(64));
    }

    public string HashRefreshToken(string refreshToken)
    {
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(refreshToken)));
    }
}
