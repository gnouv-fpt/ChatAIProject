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
        await _userRepository.SaveChangesAsync(cancellationToken);
        var response = IssueTokens(user);

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

        return IssueTokens(user);
    }

    public async Task<AuthResponseDto> RefreshTokenAsync(
        RefreshTokenRequestDto request,
        CancellationToken cancellationToken = default)
    {
        // Stateless refresh (no RefreshTokens table): the token is a signed JWT with its own
        // audience. A password change invalidates it through the security stamp; otherwise it
        // stays valid until it expires, so rotation is not single-use.
        var claims = await _jwtTokenService.ValidateRefreshTokenAsync(request.RefreshToken)
            ?? throw new UnauthorizedException(InvalidRefreshTokenMessage);

        var user = await _userRepository.GetByIdAsync(claims.UserId, cancellationToken);
        if (user is null || !string.Equals(
                claims.SecurityStamp,
                _jwtTokenService.ComputeSecurityStamp(user),
                StringComparison.Ordinal))
        {
            throw new UnauthorizedException(InvalidRefreshTokenMessage);
        }

        return IssueTokens(user);
    }

    public Task LogoutAsync(
        RefreshTokenRequestDto request,
        CancellationToken cancellationToken = default)
    {
        // Tokens live only on the client; logout means the client discards them. Server-side
        // revocation needs a per-user token version column (proposed in docs/BAO-AUTH-USER-CONTRACT.md).
        return Task.CompletedTask;
    }

    public async Task<UserProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await _userRepository.GetByIdAsync(userId, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy người dùng.");

        return MapProfile(user);
    }

    private AuthResponseDto IssueTokens(User user)
    {
        var (accessToken, accessExpiresAt) = _jwtTokenService.CreateAccessToken(user);
        var (refreshToken, refreshExpiresAt) = _jwtTokenService.CreateRefreshToken(user);

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
