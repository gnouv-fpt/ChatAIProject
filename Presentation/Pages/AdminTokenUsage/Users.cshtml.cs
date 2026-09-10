using BusinessLogic.DTOs.Responses;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.AdminTokenUsage;

[Authorize(Roles = "Admin")]
public sealed class UsersModel : AppPageModel
{
    private const string TokenAscendingSort = "token_asc";
    private const string TokenDescendingSort = "token_desc";

    private readonly ITokenUsageService _tokenUsageService;

    public UsersModel(ITokenUsageService tokenUsageService)
    {
        _tokenUsageService = tokenUsageService;
    }

    public List<UserTokenUsageViewModel> Users { get; set; } = new();

    public List<string> RoleOptions { get; set; } = new();

    [BindProperty(SupportsGet = true)]
    public string? SearchTerm { get; set; }

    [BindProperty(SupportsGet = true)]
    public string? Role { get; set; }

    [BindProperty(SupportsGet = true)]
    public string SortOrder { get; set; } = TokenDescendingSort;

    public bool HasActiveFilters =>
        !string.IsNullOrWhiteSpace(SearchTerm)
        || !string.IsNullOrWhiteSpace(Role)
        || !string.Equals(SortOrder, TokenDescendingSort, StringComparison.OrdinalIgnoreCase);

    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var usage = await _tokenUsageService.GetAdminUsageAsync(cancellationToken);
        var users = usage.Users.Select(MapUser).ToList();

        RoleOptions = users
            .Select(user => user.Role)
            .Where(role => !string.IsNullOrWhiteSpace(role))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(role => role, StringComparer.OrdinalIgnoreCase)
            .ToList();

        SortOrder = string.Equals(SortOrder, TokenAscendingSort, StringComparison.OrdinalIgnoreCase)
            ? TokenAscendingSort
            : TokenDescendingSort;

        IEnumerable<UserTokenUsageViewModel> query = users;

        if (!string.IsNullOrWhiteSpace(SearchTerm))
        {
            var keyword = SearchTerm.Trim();
            query = query.Where(user =>
                user.FullName.Contains(keyword, StringComparison.OrdinalIgnoreCase)
                || user.Email.Contains(keyword, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(Role))
        {
            query = query.Where(user => string.Equals(user.Role, Role, StringComparison.OrdinalIgnoreCase));
        }

        query = SortOrder == TokenAscendingSort
            ? query.OrderBy(user => user.TotalTokens).ThenBy(user => user.FullName, StringComparer.OrdinalIgnoreCase)
            : query.OrderByDescending(user => user.TotalTokens).ThenBy(user => user.FullName, StringComparer.OrdinalIgnoreCase);

        Users = query.ToList();
    }

    private static UserTokenUsageViewModel MapUser(UserTokenUsageDto user)
    {
        return new UserTokenUsageViewModel
        {
            UserId = user.UserId,
            FullName = user.FullName,
            Email = user.Email,
            Role = user.Role,
            PromptTokens = user.PromptTokens,
            CompletionTokens = user.CompletionTokens,
            TotalTokens = user.TotalTokens,
            AnswerCount = user.AnswerCount,
            LastUsedAt = user.LastUsedAt
        };
    }
}