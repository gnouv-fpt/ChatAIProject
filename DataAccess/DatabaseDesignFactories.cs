using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace DataAccess;

// Design time does not boot the API or require JWT/AI secrets, and never connects to SQL.
public sealed class UserDbContextFactory : IDesignTimeDbContextFactory<UserDbContext>
{
    public UserDbContext CreateDbContext(string[] args) => new(
        new DbContextOptionsBuilder<UserDbContext>().UseSqlServer(
            Environment.GetEnvironmentVariable("ConnectionStrings__UserConnection")
            ?? "Server=localhost;Database=TrafficUserDb;Trusted_Connection=True;TrustServerCertificate=True").Options);
}
public sealed class ContentDbContextFactory : IDesignTimeDbContextFactory<ContentDbContext>
{
    public ContentDbContext CreateDbContext(string[] args) => new(
        new DbContextOptionsBuilder<ContentDbContext>().UseSqlServer(
            Environment.GetEnvironmentVariable("ConnectionStrings__ContentConnection")
            ?? "Server=localhost;Database=TrafficContentDb;Trusted_Connection=True;TrustServerCertificate=True").Options);
}
