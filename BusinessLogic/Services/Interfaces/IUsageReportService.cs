using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;

namespace BusinessLogic.Services.Interfaces;

public interface IUsageReportService
{
    // Users only see their own usage; admins see everyone or one chosen user.
    Task<UsageReportDto> GetUsageAsync(
        Guid callerId,
        bool callerIsAdmin,
        UsageReportQueryDto query,
        CancellationToken cancellationToken = default);
}
