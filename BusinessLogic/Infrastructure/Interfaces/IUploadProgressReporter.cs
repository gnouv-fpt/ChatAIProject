using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Infrastructure.Interfaces;

public interface IUploadProgressReporter
{
    Task ReportAsync(
        UploadProgressDto progress,
        CancellationToken cancellationToken = default);
}
