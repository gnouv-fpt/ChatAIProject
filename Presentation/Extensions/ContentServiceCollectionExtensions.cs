using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using DataAccess.Repositories.Implementations;
using DataAccess.Repositories.Interfaces;

namespace Presentation.Extensions;

public static class ContentServiceCollectionExtensions
{
    public static IServiceCollection AddContentModule(this IServiceCollection services, IConfiguration configuration, IHostEnvironment environment)
    {
        var path = configuration["Content:BankStoragePath"] ?? Path.Combine(environment.ContentRootPath, "App_Data", "question-banks");
        services.AddSingleton<IQuestionBankRepository>(new FileQuestionBankRepository(path));
        services.AddSingleton<ICrawlJobRepository>(new FileCrawlJobRepository(Path.Combine(Path.GetDirectoryName(Path.GetFullPath(path))!, "crawl-jobs")));
        services.AddScoped<ICrawlJobService, CrawlJobService>();
        services.AddScoped<IQuestionBankService, QuestionBankService>();
        services.AddScoped<IContentMaintenanceService, ContentMaintenanceService>();
        services.AddScoped<IDocumentIndexService, DocumentIndexService>();
        services.AddSingleton(new ContentPipelineSettings {
            EnableVerifiedIndexing = configuration.GetValue<bool>("Content:EnableVerifiedIndexing") });
        return services;
    }
}
