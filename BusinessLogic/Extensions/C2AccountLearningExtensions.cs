using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Implementations;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessLogic.Extensions;

public static class C2AccountLearningExtensions
{
    public static IServiceCollection AddC2AccountLearningModule(this IServiceCollection services)
    {
        services.AddSingleton(new QuotaSettings());
        services.AddScoped<IQuotaRepository, QuotaRepository>();
        services.AddScoped<IUsageReportRepository, UsageReportRepository>();
        services.AddScoped<IQuotaService, QuotaService>();
        services.AddScoped<IUsageReportService, UsageReportService>();
        services.AddScoped<ILearningProgressRepository, C2LearningProgressRepository>();
        services.AddScoped<ILearningProgressService, LearningProgressService>();
        services.AddHttpClient<ILearningCatalogClient, LearningCatalogHttpClient>((sp, http) =>
        {
            var config = sp.GetRequiredService<Microsoft.Extensions.Configuration.IConfiguration>();
            http.BaseAddress = new Uri(config["ContentService:Address"] ?? "http://localhost:5040/");
            http.Timeout = TimeSpan.FromSeconds(10);
        });
        return services;
    }
}
