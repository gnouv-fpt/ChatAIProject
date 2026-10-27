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

    public (string Token, DateTime ExpiresAt) CreateRefreshToken(User user)
    {
        var expires = DateTime.UtcNow.AddDays(_settings.RefreshTokenDays);
        return (_tokenHandler.CreateToken(new SecurityTokenDescriptor
        {
            Issuer = _settings.Issuer, Audience = _settings.Audience + ".Refresh",
            TokenType = "refresh+jwt", Expires = expires, IssuedAt = DateTime.UtcNow,
            SigningCredentials = _signingCredentials,
            Claims = new Dictionary<string, object>
            {
                [AppClaimTypes.UserId] = user.Id.ToString(),
                [JwtRegisteredClaimNames.Jti] = Guid.NewGuid().ToString()
            }
        }), expires);
    }

    public async Task<(Guid UserId, DateTime ExpiresAt)?> ValidateRefreshTokenAsync(string token)
    {
        var result = await _tokenHandler.ValidateTokenAsync(token, new TokenValidationParameters
        {
            ValidateIssuer = true, ValidIssuer = _settings.Issuer,
            ValidateAudience = true, ValidAudience = _settings.Audience + ".Refresh",
            ValidateIssuerSigningKey = true, IssuerSigningKey = _signingCredentials.Key,
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256], ValidTypes = ["refresh+jwt"],
            ValidateLifetime = true, RequireExpirationTime = true, ClockSkew = TimeSpan.Zero
        });
        if (!result.IsValid || result.SecurityToken is not JsonWebToken jwt ||
            !Guid.TryParse(jwt.Subject, out var id)) return null;
        return (id, jwt.ValidTo);
    }

    public string CreateContentServiceToken() => _tokenHandler.CreateToken(new SecurityTokenDescriptor
    {
        Issuer = _settings.Issuer, Audience = _settings.Audience + ".ContentService",
        TokenType = "service+jwt", Expires = DateTime.UtcNow.AddMinutes(1),
        SigningCredentials = _signingCredentials,
        Claims = new Dictionary<string, object> { ["scope"] = "content.read" }
    });
}
