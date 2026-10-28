using BusinessLogic.Exams;
using Confluent.Kafka;
using StackExchange.Redis;

namespace Presentation.Exams;

public static class ExamModuleRegistration
{
    public static IServiceCollection AddCustomExamModule(this IServiceCollection services, IConfiguration config)
    {
        services.AddSingleton<IConnectionMultiplexer>(_ =>
        {
            var value = config.GetConnectionString("Redis")
                ?? throw new InvalidOperationException("ConnectionStrings:Redis is required.");
            return ConnectionMultiplexer.Connect(value);
        });
        services.AddSingleton<RedisCustomExamStore>();
        services.AddSingleton<ICustomExamStore>(sp => sp.GetRequiredService<RedisCustomExamStore>());
        services.AddSingleton<RedisNotificationInbox>();
        services.AddSingleton(TimeProvider.System);
        services.AddScoped<CustomExamService>();
        services.AddSingleton<IProducer<string, string>>(_ =>
        {
            var bootstrap = config["Exams:Kafka:BootstrapServers"]
                ?? throw new InvalidOperationException("Exams:Kafka:BootstrapServers is required.");
            return new ProducerBuilder<string, string>(new ProducerConfig
            {
                BootstrapServers = bootstrap,
                Acks = Acks.All,
                EnableIdempotence = true,
                MessageTimeoutMs = 10000
            }).Build();
        });
        services.AddSingleton<IExamEventPublisher, KafkaExamEventPublisher>();
        services.AddHttpClient<IExamQuestionSource, ContentQuestionClient>(client =>
        {
            var baseUrl = config["Exams:ContentBaseUrl"];
            if (!string.IsNullOrWhiteSpace(baseUrl)) client.BaseAddress = new Uri(baseUrl);
        });
        services.AddHttpClient<IExamResultSink, UserExamResultClient>(client =>
        {
            var baseUrl = config["Exams:UserBaseUrl"];
            if (!string.IsNullOrWhiteSpace(baseUrl)) client.BaseAddress = new Uri(baseUrl);
        });
        return services;
    }
}
