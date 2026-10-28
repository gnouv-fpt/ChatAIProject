using Confluent.Kafka;
using BusinessLogic.Exams;
using StackExchange.Redis;
using WorkerService;

var builder = Host.CreateApplicationBuilder(args);
var config = builder.Configuration;
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
builder.Services.AddHostedService<ExamNotificationWorker>();
builder.Services.AddHostedService<CustomExamDeadlineWorker>();

var host = builder.Build();
await host.RunAsync();
