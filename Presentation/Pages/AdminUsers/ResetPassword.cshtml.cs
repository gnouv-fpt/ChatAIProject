using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.AdminUsers;

[Authorize(Roles = "Admin")]
public sealed class ResetPasswordModel : AppPageModel
{
    private readonly IUserManagementService _userManagementService;

    public ResetPasswordModel(IUserManagementService userManagementService)
    {
        _userManagementService = userManagementService;
    }

    [BindProperty]
    public AdminResetPasswordViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(int id, CancellationToken cancellationToken)
    {
        var user = await _userManagementService.GetUserAsync(id, cancellationToken);
        if (user is null)
        {
            return NotFound("Không tìm thấy tài khoản.");
        }

        ViewModel = new AdminResetPasswordViewModel
        {
            UserId = user.Id,
            UserDisplayName = $"{user.FullName} ({user.Email})"
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            return Page();
        }

        var result = await _userManagementService.ResetPasswordAsync(
            new ResetPasswordRequestDto(ViewModel.UserId, ViewModel.NewPassword),
            cancellationToken);

        if (!result.Succeeded)
        {
            ModelState.AddModelError(string.Empty, result.Message);
            return Page();
        }

        TempData["SuccessMessage"] = result.Message;
        return RedirectToPage("/AdminUsers/Index");
    }
}
