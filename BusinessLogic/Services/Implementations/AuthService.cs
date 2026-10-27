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
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly AuthSettings _authSettings;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        IUserRepository userRepository,
        IPasswordHasher passwordHasher,
        IJwtTokenService jwtTokenService,
        AuthSettings authSettings,
        ILogger<AuthService> logger)
    {
        _userRepository = userRepository;
        _passwordHasher = passwordHasher;
        _jwtTokenService = jwtTokenService;
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
        var refresh = await _jwtTokenService.ValidateRefreshTokenAsync(request.RefreshToken)
            ?? throw new UnauthorizedException(InvalidRefreshTokenMessage);
        var user = await _userRepository.GetByIdAsync(refresh.UserId, cancellationToken)
            ?? throw new UnauthorizedException(InvalidRefreshTokenMessage);
        var (accessToken, accessExpires) = _jwtTokenService.CreateAccessToken(user);
        // Same signed client-held token and absolute expiry; refreshing does not extend its lifetime.
        return new(accessToken, accessExpires, request.RefreshToken, refresh.ExpiresAt, MapProfile(user));
    }

    public Task LogoutAsync(
        RefreshTokenRequestDto request,
        CancellationToken cancellationToken = default)
    {
        // Stateless logout: client must clear both tokens. No server-side per-token revocation.
        cancellationToken.ThrowIfCancellationRequested();
        return Task.CompletedTask;
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
        var (refreshToken, refreshExpiresAt) = _jwtTokenService.CreateRefreshToken(user);
        await _userRepository.SaveChangesAsync(cancellationToken);

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
