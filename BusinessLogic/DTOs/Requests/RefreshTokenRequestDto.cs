using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests;

public sealed class RefreshTokenRequestDto
{
    [Required(ErrorMessage = "Thiếu refresh token.")]
    public string RefreshToken { get; set; } = string.Empty;
}
