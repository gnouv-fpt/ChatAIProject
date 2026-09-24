using System.Text;

namespace BusinessLogic.Infrastructure.Settings;

public sealed class JwtSettings
{
    public const string SectionName = "Jwt";

    public string Issuer { get; set; } = "ChatAIWeb";

    public string Audience { get; set; } = "ChatAIWeb.Clients";

    public string SecretKey { get; set; } = string.Empty;

    public int AccessTokenMinutes { get; set; } = 60;

    public int RefreshTokenDays { get; set; } = 7;

    public void EnsureValid()
    {
        if (Encoding.UTF8.GetByteCount(SecretKey) < 32)
        {
            throw new InvalidOperationException(
                "Jwt:SecretKey is missing or shorter than 32 bytes. " +
                "Set it via `dotnet user-secrets set \"Jwt:SecretKey\" \"<value>\"` or the Jwt__SecretKey environment variable.");
        }
    }
}
