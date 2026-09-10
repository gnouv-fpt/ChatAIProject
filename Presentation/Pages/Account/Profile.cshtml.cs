using System.Security.Claims;
using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.Account;

[Authorize]
public sealed class ProfileModel : AppPageModel
{
    private readonly IAccountService _accountService;

    public ProfileModel(IAccountService accountService)
    {
        _accountService = accountService;
    }

    [BindProperty]
    public ProfileViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        var profile = await _accountService.GetProfileAsync(GetCurrentUserId(), cancellationToken);
        if (profile is null)
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToPage("/Account/Login");
        }

        ViewModel = MapProfile(profile);
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        var result = await _accountService.UpdateProfileAsync(
            new UpdateProfileRequestDto(
                GetCurrentUserId(),
                ViewModel.FullName,
                ViewModel.Email,
                ViewModel.CurrentPassword,
                ViewModel.NewPassword),
            cancellationToken);

        if (!result.Succeeded)
        {
            ModelState.AddModelError(string.Empty, result.Message);
            return Page();
        }

        var profile = await _accountService.GetProfileAsync(GetCurrentUserId(), cancellationToken);
        if (profile is not null)
        {
            await HttpContext.SignInAsync(
                CookieAuthenticationDefaults.AuthenticationScheme,
                CreatePrincipal(new AuthUserDto(profile.Id, profile.FullName, profile.Email, profile.Role)));
        }

        TempData["SuccessMessage"] = result.Message;
        return RedirectToPage("/Account/Profile");
    }

    private ClaimsPrincipal CreatePrincipal(AuthUserDto user)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.FullName),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.Role)
        };

        var identity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
        return new ClaimsPrincipal(identity);
    }

    private static ProfileViewModel MapProfile(AccountProfileDto profile)
    {
        return new ProfileViewModel
        {
            Id = profile.Id,
            FullName = profile.FullName,
            Email = profile.Email,
            Role = profile.Role
        };
    }
}
