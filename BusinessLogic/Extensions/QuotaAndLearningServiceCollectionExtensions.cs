using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Implementations;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.DependencyInjection;

namespace BusinessLogic.Extensions;

public static class QuotaAndLearningServiceCollectionExtensions
{
    // Quota, learning persistence and report services. Usable by the REST host and the Worker host;
    // the caller registers ChatAIWebDbContext, IUserRepository and the open IGenericRepository<>,
    // and binds QuotaSettings from the "Quota" configuration section.
    public static IServiceCollection AddQuotaAndLearningData(this IServiceCollection services, QuotaSettings quotaSettings)
    {
        services.AddSingleton(quotaSettings);

        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddScoped<IQuotaRepository, QuotaRepository>();
        services.AddScoped<IUsageReportRepository, UsageReportRepository>();
        services.AddScoped<IQuestionBankRepository, QuestionBankRepository>();
        services.AddScoped<ILearningAttemptRepository, LearningAttemptRepository>();
        services.AddScoped<ILearningProgressRepository, LearningProgressRepository>();
        services.AddScoped<IQuestionBookmarkRepository, QuestionBookmarkRepository>();
        services.AddScoped<IChatAttachmentRepository, ChatAttachmentRepository>();

        services.AddScoped<IQuotaService, QuotaService>();
        services.AddScoped<ILearningProgressService, LearningProgressService>();
        services.AddScoped<IUsageReportService, UsageReportService>();
        return services;
    }
}
