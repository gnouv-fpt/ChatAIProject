using BusinessLogic.DTOs.Requests;

namespace BusinessLogic.Services.Interfaces;

public interface ISystemSettingsService
{
    Task<SystemSettingsDto> GetSettingsAsync(CancellationToken cancellationToken = default);

    Task SaveSettingsAsync(SystemSettingsDto settings, CancellationToken cancellationToken = default);
}
