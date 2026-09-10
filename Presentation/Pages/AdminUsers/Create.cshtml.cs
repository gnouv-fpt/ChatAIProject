using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Presentation.Models;

namespace Presentation.Pages.AdminUsers;

[Authorize(Roles = "Admin")]
public sealed class CreateModel : AppPageModel
{
    private readonly IUserManagementService _userManagementService;

    public CreateModel(IUserManagementService userManagementService)
    {
        _userManagementService = userManagementService;
    }

    [BindProperty]
    public AdminCreateUserViewModel ViewModel { get; set; } = new();

    public void OnGet()
    {
        PopulateRoles();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            PopulateRoles(ViewModel.Role);
            return Page();
        }

        var result = await _userManagementService.CreateUserAsync(
            new CreateUserRequestDto(
                ViewModel.FullName,
                ViewModel.Email,
                ViewModel.Role,
                ViewModel.Password,
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
