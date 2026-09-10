using System.Security.Claims;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Pages;

public abstract class AppPageModel : PageModel
{
    protected int GetCurrentUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(value, out var userId) ? userId : 0;
    }

    protected string? GetCurrentUserRole()
    {
        return User.FindFirstValue(ClaimTypes.Role);
    }
}
