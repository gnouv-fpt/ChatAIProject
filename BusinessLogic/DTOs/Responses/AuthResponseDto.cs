namespace BusinessLogic.DTOs.Responses;

public sealed record AuthResponseDto(
    string AccessToken,
    DateTime AccessTokenExpiresAt,
    string RefreshToken,
    DateTime RefreshTokenExpiresAt,
    UserProfileDto User);
