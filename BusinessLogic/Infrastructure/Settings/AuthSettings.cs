namespace BusinessLogic.Infrastructure.Settings;

public sealed class AuthSettings
{
    public const string SectionName = "Auth";

    public int DefaultTokenQuota { get; set; } = 100_000;

    public SeedAdminSettings SeedAdmin { get; set; } = new();
}

public sealed class SeedAdminSettings
{
    public string Username { get; set; } = "admin";

    public string Email { get; set; } = string.Empty;

    public string Password { get; set; } = string.Empty;
}
