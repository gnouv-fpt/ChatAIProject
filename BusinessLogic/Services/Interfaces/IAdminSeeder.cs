namespace BusinessLogic.Services.Interfaces;

public interface IAdminSeeder
{
    Task SeedAsync(CancellationToken cancellationToken = default);
}
