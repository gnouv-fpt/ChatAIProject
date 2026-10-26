namespace BusinessLogic.Services.Interfaces;

public sealed record ContentMaintenanceResult(int ExpiredDocuments, int InvalidatedChunks);
public interface IContentMaintenanceService
{
    Task<ContentMaintenanceResult> RunAsync(CancellationToken cancellationToken = default);
}
