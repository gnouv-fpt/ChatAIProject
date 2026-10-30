using BusinessLogic.Extensions;
using BusinessLogic.Infrastructure.Settings;
using Presentation.BackgroundJobs;

namespace Presentation.Extensions;

public static class AccountLearningModuleExtensions
{
    // Bảo's module for the REST host: quota, learning progress/history/bookmarks and usage reports.
    public static IServiceCollection AddAccountLearningModule(this IServiceCollection services, IConfiguration configuration)
    {
        var quotaSettings = configuration.GetSection(QuotaSettings.SectionName).Get<QuotaSettings>() ?? new QuotaSettings();
        services.AddQuotaAndLearningData(quotaSettings);

        if (quotaSettings.RecoveryEnabled)
        {
            services.AddHostedService<QuotaRecoveryJob>();
        }

        return services;
    }
}
