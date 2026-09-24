using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class AdminSeeder : IAdminSeeder
{
    private readonly IUserRepository _userRepository;
    private readonly IPasswordHasher _passwordHasher;
    private readonly AuthSettings _authSettings;
    private readonly ILogger<AdminSeeder> _logger;

    public AdminSeeder(
        IUserRepository userRepository,
        IPasswordHasher passwordHasher,
        AuthSettings authSettings,
        ILogger<AdminSeeder> logger)
    {
        _userRepository = userRepository;
        _passwordHasher = passwordHasher;
        _authSettings = authSettings;
        _logger = logger;
    }

    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        var seed = _authSettings.SeedAdmin;
        if (string.IsNullOrWhiteSpace(seed.Email) || string.IsNullOrWhiteSpace(seed.Password))
        {
            _logger.LogWarning("Auth:SeedAdmin is not configured; skipping admin account seeding.");
            return;
        }

        var email = seed.Email.Trim().ToLowerInvariant();
        if (await _userRepository.EmailExistsAsync(email, cancellationToken))
        {
            return;
        }

        await _userRepository.AddAsync(new User
        {
            Id = Guid.NewGuid(),
            Username = seed.Username.Trim(),
            Email = email,
            PasswordHash = _passwordHasher.HashPassword(seed.Password),
            Role = UserRole.Admin,
            TokenQuota = _authSettings.DefaultTokenQuota,
            TokenBalance = _authSettings.DefaultTokenQuota,
            CreatedAt = DateTime.UtcNow
        }, cancellationToken);
        await _userRepository.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Seeded admin account {Email}", email);
    }
}
