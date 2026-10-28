using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Infrastructure.Implementations;
using DataAccess.Repositories.Implementations;
using DataAccess.Repositories.Interfaces;

namespace Presentation.Extensions;

public static class ContentServiceCollectionExtensions
{
    public static IServiceCollection AddContentModule(this IServiceCollection services, IConfiguration configuration, IHostEnvironment environment)
    {
        var path = configuration["Content:CrawlJobStoragePath"] ?? Path.Combine(environment.ContentRootPath, "App_Data", "crawl-jobs");
        services.AddScoped<IQuestionBankRepository, PendingSqlQuestionBankRepository>();
        services.AddSingleton<ICrawlJobRepository>(new FileCrawlJobRepository(path));
        services.AddScoped<ICrawlJobService, CrawlJobService>();
        services.AddScoped<IQuestionBankService, QuestionBankService>();
        services.AddScoped<IContentMaintenanceService, ContentMaintenanceService>();
        services.AddScoped<IDocumentIndexService, DocumentIndexService>();
        services.AddSingleton(new AnimationSettings {
            AllowedHosts = configuration.GetSection("Content:AnimationAllowedHosts").Get<string[]>() ?? [] });
        services.AddScoped<IContentManifestService, ContentManifestService>();
        services.AddHttpClient<ILegalSourcePreviewService, LegalSourcePreviewService>(client => {
            client.Timeout = TimeSpan.FromSeconds(30);
            client.DefaultRequestHeaders.UserAgent.ParseAdd("ChatAIWeb-content-preview/1.0");
        }).ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        // Configure the existing typed crawler client without changing the shared REST host.
        services.AddHttpClient<ICrawlerService, CrawlerService>()
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.AddSingleton(new ContentPipelineSettings {
            EnableVerifiedIndexing = configuration.GetValue<bool>("Content:EnableVerifiedIndexing") });
        return services;
    }
}
