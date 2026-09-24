using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

public interface IAuthService
{
    Task<AuthResponseDto> RegisterAsync(RegisterRequestDto request, CancellationToken cancellationToken = default);

    Task<AuthResponseDto> LoginAsync(LoginRequestDto request, CancellationToken cancellationToken = default);

    Task<AuthResponseDto> RefreshTokenAsync(RefreshTokenRequestDto request, CancellationToken cancellationToken = default);

    Task LogoutAsync(RefreshTokenRequestDto request, CancellationToken cancellationToken = default);

    Task<UserProfileDto> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default);
}
