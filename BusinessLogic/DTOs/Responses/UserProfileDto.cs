using BusinessObject.Enums;

namespace BusinessLogic.DTOs.Responses;

public sealed record UserProfileDto(
    Guid Id,
    string Username,
    string Email,
    UserRole Role,
    int TokenQuota,
    int TokenBalance,
    DateTime CreatedAt);
