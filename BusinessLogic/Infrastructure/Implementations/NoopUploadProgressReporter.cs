using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Infrastructure.Implementations;

public sealed class NoopUploadProgressReporter : IUploadProgressReporter
{
    public Task ReportAsync(
        UploadProgressDto progress,
        CancellationToken cancellationToken = default)
    {
        return Task.CompletedTask;
    }
}
