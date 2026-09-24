using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class AuthService : IAuthService
{
    private const string InvalidCredentialsMessage = "Email hoặc mật khẩu không đúng.";
    private const string InvalidRefreshTokenMessage = "Refresh token không hợp lệ hoặc đã hết hạn.";

    private readonly IUserRepository _userRepository;
    private readonly IRefreshTokenRepository _refreshTokenRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly JwtSettings _jwtSettings;
    private readonly AuthSettings _authSettings;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        IUserRepository userRepository,
        IRefreshTokenRepository refreshTokenRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenService jwtTokenService,
        JwtSettings jwtSettings,
        AuthSettings authSettings,
        ILogger<AuthService> logger)
    {
        _userRepository = userRepository;
        _refreshTokenRepository = refreshTokenRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
        _jwtSettings = jwtSettings;
        _authSettings = authSettings;
        _logger = logger;
    }

    public async Task<AuthResponseDto> RegisterAsync(
        RegisterRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var username = request.Username.Trim();
        var email = NormalizeEmail(request.Email);

        if (await _userRepository.UsernameExistsAsync(username, cancellationToken))
        {
            throw new ConflictException("Tên đăng nhập đã được sử dụng.");
        }

        if (await _userRepository.EmailExistsAsync(email, cancellationToken))
        {
            throw new ConflictException("Email đã được sử dụng.");
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = username,
            Email = email,
            PasswordHash = _passwordHasher.HashPassword(request.Password),
            Role = UserRole.User,
            TokenQuota = _authSettings.DefaultTokenQuota,
            TokenBalance = _authSettings.DefaultTokenQuota,
            CreatedAt = DateTime.UtcNow
        };

        await _userRepository.AddAsync(user, cancellationToken);
        var response = await IssueTokensAsync(user, cancellationToken);

        _logger.LogInformation("User {UserId} registered", user.Id);
        return response;
    }

    public async Task<AuthResponseDto> LoginAsync(
        LoginRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var user = await _userRepository.GetByEmailAsync(NormalizeEmail(request.Email), cancellationToken);
        if (user is null || !_passwordHasher.VerifyPassword(request.Password, user.PasswordHash))
        {
            throw new UnauthorizedException(InvalidCredentialsMessage);
        }

        return await IssueTokensAsync(user, cancellationToken);
    }

    public async Task<AuthResponseDto> RefreshTokenAsync(
        RefreshTokenRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var storedToken = await _refreshTokenRepository.GetByTokenHashWithUserAsync(
            _jwtTokenService.HashRefreshToken(request.RefreshToken),
            cancellationToken);

        if (storedToken is null || !storedToken.IsActive(DateTime.UtcNow))
        {
            throw new UnauthorizedException(InvalidRefreshTokenMessage);
        }

        // Rotation: each refresh token is single-use.
        storedToken.RevokedAt = DateTime.UtcNow;
        return await IssueTokensAsync(storedToken.User, cancellationToken);
    }

    public async Task LogoutAsync(
        RefreshTokenRequestDto request,
        CancellationToken cancellationToken = default)
    {
        var storedToken = await _refreshTokenRepository.GetByTokenHashWithUserAsync(
            _jwtTokenService.HashRefreshToken(request.RefreshToken),
            cancellationToken);

        if (storedToken is null || storedToken.RevokedAt is not null)
        {
            return;
        }

        storedToken.RevokedAt = DateTime.UtcNow;
        await _refreshTokenRepository.SaveChangesAsync(cancellationToken);
    }

    public async Task<UserProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await _userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy người dùng.");

        return MapProfile(user);
    }

    private async Task<AuthResponseDto> IssueTokensAsync(User user, CancellationToken cancellationToken)
    {
        var (accessToken, accessExpiresAt) = _jwtTokenService.CreateAccessToken(user);
        var refreshToken = _jwtTokenService.GenerateRefreshToken();
        var refreshExpiresAt = DateTime.UtcNow.AddDays(_jwtSettings.RefreshTokenDays);

        await _refreshTokenRepository.AddAsync(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = _jwtTokenService.HashRefreshToken(refreshToken),
            ExpiresAt = refreshExpiresAt,
            CreatedAt = DateTime.UtcNow
        }, cancellationToken);

        // Repositories share the scoped DbContext, so this also persists pending user/token changes.
        await _refreshTokenRepository.SaveChangesAsync(cancellationToken);

        return new AuthResponseDto(accessToken, accessExpiresAt, refreshToken, refreshExpiresAt, MapProfile(user));
    }

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();

    private static UserProfileDto MapProfile(User user)
    {
        return new UserProfileDto(
            user.Id,
            user.Username,
            user.Email,
            user.Role,
            user.TokenQuota,
            user.TokenBalance,
            user.CreatedAt);
    }
}
