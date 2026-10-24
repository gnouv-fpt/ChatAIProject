using DataAccess;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;

namespace Presentation.Infrastructure;

public sealed class DatabaseHealthCheck(IServiceScopeFactory scopes) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken ct = default)
    {
        using var scope = scopes.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ChatAIWebDbContext>();
        if (!await db.Database.CanConnectAsync(ct)) return HealthCheckResult.Unhealthy("SQL unavailable");
        return (await db.Database.GetPendingMigrationsAsync(ct)).Any()
            ? HealthCheckResult.Unhealthy("SQL migrations pending") : HealthCheckResult.Healthy();
    }
}
