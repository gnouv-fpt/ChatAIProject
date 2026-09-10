using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Presentation.Models;

namespace Presentation.Pages.AdminUsers;

[Authorize(Roles = "Admin")]
public sealed class EditModel : AppPageModel
{
    private readonly IUserManagementService _userManagementService;

    public EditModel(IUserManagementService userManagementService)
    {
        _userManagementService = userManagementService;
    }

    [BindProperty]
    public AdminEditUserViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(int id, CancellationToken cancellationToken)
    {
        var user = await _userManagementService.GetUserAsync(id, cancellationToken);
        if (user is null)
        {
            return NotFound("Không tìm thấy tài khoản.");
        }

        PopulateRoles(user.Role);
        ViewModel = new AdminEditUserViewModel
        {
            Id = user.Id,
            FullName = user.FullName,
            Email = user.Email,
            Role = user.Role,
            IsActive = user.IsActive
        };
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            PopulateRoles(ViewModel.Role);
            return Page();
        }

        var result = await _userManagementService.UpdateUserAsync(
            new UpdateUserRequestDto(
                ViewModel.Id,
                GetCurrentUserId(),
                ViewModel.FullName,
                ViewModel.Email,
                ViewModel.Role,
                ViewModel.IsActive),
            cancellationToken);

        if (!result.Succeeded)
        {
            ModelState.AddModelError(string.Empty, result.Message);
            PopulateRoles(ViewModel.Role);
            return Page();
        }

        TempData["SuccessMessage"] = result.Message;
        return RedirectToPage("/AdminUsers/Index");
    }

    private void PopulateRoles(string? selectedRole = null)
    {
        ViewData["Roles"] = UserRoleNames.All
            .Select(role => new SelectListItem(role, role, role == selectedRole))
            .ToList();
    }
}
