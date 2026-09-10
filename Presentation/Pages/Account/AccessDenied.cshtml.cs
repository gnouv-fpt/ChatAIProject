using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Presentation.Pages.Account;

[AllowAnonymous]
public sealed class AccessDeniedModel : PageModel
{
}
