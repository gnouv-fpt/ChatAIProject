using System.Security.Claims;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure;

namespace Presentation.Extensions;

public static class ClaimsPrincipalExtensions
{
    public static Guid GetUserId(this ClaimsPrincipal principal)
    {
        var value = principal.FindFirstValue(AppClaimTypes.UserId);
        return Guid.TryParse(value, out var userId)
            ? userId
            : throw new UnauthorizedException("Access token không hợp lệ.");
    }
}
