using System.Security.Cryptography;
using BusinessLogic.Infrastructure.Implementations;
using BusinessLogic.Infrastructure.Settings;
using BusinessObject.Entities;
using BusinessObject.Enums;
using Xunit;

namespace ChatAIWeb.Tests.AccountLearning;

// Stateless refresh tokens (no RefreshTokens table); runs without a database.
public sealed class JwtTokenServiceTests
{
    private static JwtSettings Settings(string? secret = null) => new()
    {
        SecretKey = secret ?? Convert.ToBase64String(RandomNumberGenerator.GetBytes(48)),
        RefreshTokenDays = 7
    };

    private static User NewUser(string passwordHash = "hash-1") => new()
    {
        Id = Guid.NewGuid(),
        Username = "alice",
        Email = "alice@test.local",
        PasswordHash = passwordHash,
        Role = UserRole.User,
        CreatedAt = DateTime.UtcNow
    };

    [Fact]
    public async Task RefreshTokenRoundTripsUserAndStamp()
    {
        var service = new JwtTokenService(Settings());
        var user = NewUser();

        var (token, expiresAt) = service.CreateRefreshToken(user);
        var claims = await service.ValidateRefreshTokenAsync(token);

        Assert.NotNull(claims);
        Assert.Equal(user.Id, claims!.UserId);
        Assert.Equal(service.ComputeSecurityStamp(user), claims.SecurityStamp);
        Assert.InRange(expiresAt, DateTime.UtcNow.AddDays(7).AddMinutes(-1), DateTime.UtcNow.AddDays(7).AddMinutes(1));
    }

    [Fact]
    public async Task AccessTokenIsNotAcceptedAsRefreshToken()
    {
        var service = new JwtTokenService(Settings());
        var (accessToken, _) = service.CreateAccessToken(NewUser());

        Assert.Null(await service.ValidateRefreshTokenAsync(accessToken));
        Assert.Null(await service.ValidateRefreshTokenAsync(""));
        Assert.Null(await service.ValidateRefreshTokenAsync("not-a-jwt"));
    }

    [Fact]
    public async Task TokenSignedWithAnotherKeyIsRejected()
    {
        var (foreign, _) = new JwtTokenService(Settings()).CreateRefreshToken(NewUser());

        Assert.Null(await new JwtTokenService(Settings()).ValidateRefreshTokenAsync(foreign));
    }

    [Fact]
    public async Task ExpiredRefreshTokenIsRejected()
    {
        var secret = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
        var expired = Settings(secret);
        expired.RefreshTokenDays = -1;
        var (token, _) = new JwtTokenService(expired).CreateRefreshToken(NewUser());

        Assert.Null(await new JwtTokenService(Settings(secret)).ValidateRefreshTokenAsync(token));
    }

    [Fact]
    public void PasswordChangeChangesSecurityStamp()
    {
        var service = new JwtTokenService(Settings());
        var user = NewUser("hash-1");
        var before = service.ComputeSecurityStamp(user);

        user.PasswordHash = "hash-2";

        Assert.NotEqual(before, service.ComputeSecurityStamp(user));
        Assert.DoesNotContain("hash", before, StringComparison.OrdinalIgnoreCase);
    }
}
