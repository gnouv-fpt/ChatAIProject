using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using BusinessLogic.Infrastructure.Implementations;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using Confluent.Kafka;
using BusinessLogic.Exams;
using StackExchange.Redis;
using WorkerService;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;
builder.Services.AddOpenTelemetry().ConfigureResource(r => r.AddService("worker-service"))
    .WithTracing(t => t.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation()
        .AddSource(ExamEventTelemetry.Name).AddOtlpExporter())
    .WithMetrics(m => m.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation()
        .AddMeter(ExamEventTelemetry.Name).AddPrometheusExporter());
builder.Logging.AddProvider(new Presentation.Infrastructure.SafeFileLoggerProvider(
    config["Logging:FilePath"] ?? "logs/worker.jsonl",
    config.GetValue<long?>("Logging:MaxFileBytes") ?? 10 * 1024 * 1024,
    config.GetValue<int?>("Logging:RetentionDays") ?? 7));
var jwt = config.GetSection("Jwt").Get<JwtSettings>() ?? new();
jwt.EnsureValid();
builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
var bootstrap = config["Exams:Kafka:BootstrapServers"]
    ?? throw new InvalidOperationException("Exams:Kafka:BootstrapServers is required.");
builder.Services.AddSingleton<IConnectionMultiplexer>(_ => ConnectionMultiplexer.Connect(
    config.GetConnectionString("Redis")
        ?? throw new InvalidOperationException("ConnectionStrings:Redis is required.")));
builder.Services.AddSingleton<RedisCustomExamStore>();
builder.Services.AddSingleton<ICustomExamStore>(sp => sp.GetRequiredService<RedisCustomExamStore>());
builder.Services.AddSingleton<IExamDeadlineQueue>(sp => sp.GetRequiredService<RedisCustomExamStore>());
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<CustomExamService>();
builder.Services.AddHttpClient<IExamQuestionSource, ContentQuestionClient>(client =>
{
    var url = config["Exams:ContentBaseUrl"];
    if (!string.IsNullOrWhiteSpace(url)) client.BaseAddress = new Uri(url);
});
builder.Services.AddHttpClient<IExamResultSink, UserExamResultClient>(client =>
{
    var url = config["Exams:UserBaseUrl"];
    if (!string.IsNullOrWhiteSpace(url)) client.BaseAddress = new Uri(url);
});
builder.Services.AddSingleton<IProducer<string, string>>(_ =>
    new ProducerBuilder<string, string>(new ProducerConfig
    {
        BootstrapServers = bootstrap,
        Acks = Acks.All,
        EnableIdempotence = true
    }).Build());
builder.Services.AddSingleton<RedisNotificationInbox>();
builder.Services.AddSingleton<IExamEventPublisher, KafkaExamEventPublisher>();
builder.Services.AddHttpClient<IContentMaintenanceService, ContentMaintenanceHttpClient>(client =>
{
    client.BaseAddress = new Uri(config["ContentService:Address"] ?? "http://localhost:5040/");
    client.Timeout = TimeSpan.FromSeconds(60);
});
builder.Services.AddHostedService<ContentMaintenanceWorker>();
builder.Services.AddHostedService<ExamNotificationWorker>();
builder.Services.AddHostedService<CustomExamDeadlineWorker>();

var host = builder.Build();
host.MapGet("/health/live", () => Results.Ok(new { status = "alive" }));
host.MapPrometheusScrapingEndpoint();
await host.RunAsync();
