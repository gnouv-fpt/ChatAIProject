using System.Text;
using System.Text.Json.Serialization;
using BusinessLogic.Infrastructure;
using BusinessLogic.Infrastructure.Implementations;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Protos;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using DataAccess;
using DataAccess.Repositories.Implementations;
using DataAccess.Repositories.Interfaces;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Presentation.BackgroundJobs;
using Presentation.Extensions;
using Presentation.Middleware;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

// ==================== Settings ====================
var jwtSettings = builder.Configuration.GetSection(JwtSettings.SectionName).Get<JwtSettings>() ?? new JwtSettings();
jwtSettings.EnsureValid();
var authSettings = builder.Configuration.GetSection(AuthSettings.SectionName).Get<AuthSettings>() ?? new AuthSettings();
builder.Services.AddSingleton(jwtSettings);
builder.Services.AddSingleton(authSettings);

// ==================== Web API ====================
builder.Services.AddControllers()
    .AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddHealthChecks().AddCheck<Presentation.Infrastructure.DatabaseHealthCheck>("sql");
var chatSettings = builder.Configuration.GetSection("Chat").Get<ChatSettings>() ?? new();
if (chatSettings.ReservationTokens < 1 || chatSettings.InferenceTimeoutSeconds is < 1 or > 300 ||
    chatSettings.MaxAttachmentBytes is < 1024 or > 5 * 1024 * 1024 || chatSettings.AttachmentRetentionHours < 1)
    throw new InvalidOperationException("Invalid Chat configuration.");
builder.Services.AddSingleton(chatSettings);
builder.Services.AddScoped<IAttachmentService, PrivateAttachmentService>();
builder.Services.AddHostedService<AttachmentCleanupService>();
builder.Services.AddHostedService<Presentation.Infrastructure.OutboxMetricsService>();
builder.Services.AddOpenTelemetry().ConfigureResource(r => r.AddService("rest-api-service"))
    .WithTracing(t => t.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation().AddOtlpExporter())
    .WithMetrics(m => m.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation()
        .AddMeter("ChatAIWeb.Chat", "ChatAIWeb.Chat.Outbox").AddPrometheusExporter());
builder.Logging.AddProvider(new Presentation.Infrastructure.SafeFileLoggerProvider(
    builder.Configuration["Logging:FilePath"] ?? "logs/rest-api.jsonl"));

// ==================== Authentication ====================
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.MapInboundClaims = false;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtSettings.Issuer,
            ValidateAudience = true,
            ValidAudience = jwtSettings.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.SecretKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30),
            NameClaimType = AppClaimTypes.Username,
            RoleClaimType = AppClaimTypes.Role
        };
        options.Events = JwtProblemDetailsEvents.Create();
    });
builder.Services.AddAuthorization();

// ==================== Swagger ====================
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Vietnam Traffic Law RAG - REST API",
        Version = "v1"
    });

    var bearerScheme = new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Description = "Dán access token (không cần tiền tố \"Bearer \").",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
    };
    options.AddSecurityDefinition("Bearer", bearerScheme);
    options.AddSecurityRequirement(new OpenApiSecurityRequirement { [bearerScheme] = Array.Empty<string>() });
});

// ==================== Database ====================
builder.Services.AddDbContext<ChatAIWebDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        sqlOptions => sqlOptions.EnableRetryOnFailure()));

// ==================== Repository injection ====================
builder.Services.AddScoped(typeof(IGenericRepository<>), typeof(GenericRepository<>));
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
builder.Services.AddScoped<IChatSessionRepository, ChatSessionRepository>();
builder.Services.AddScoped<IChatMessageRepository, ChatMessageRepository>();
builder.Services.AddScoped<IChatTurnRepository, ChatTurnRepository>();
builder.Services.AddHttpClient<ICrawlerService, CrawlerService>(client =>
{
    client.Timeout = TimeSpan.FromMinutes(2);
    client.DefaultRequestHeaders.UserAgent.ParseAdd("ChatAIWeb legal document crawler");
});
builder.Services.AddScoped<IDocumentRepository, DocumentRepository>();

// ==================== Services injection ====================
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IAdminSeeder, AdminSeeder>();
builder.Services.AddScoped<IChatbotService, ChatbotService>();
builder.Services.AddScoped<IDocumentService, DocumentService>();
builder.Services.AddAccountLearningModule(builder.Configuration);
// Preserve Phuc's current scheduler until the Worker host takes ownership.
if (builder.Configuration.GetValue("Jobs:EnableLegacyMidnight", true))
    builder.Services.AddHostedService<MidnightCleanupJob>();

// ==================== gRPC Client ====================
var grpcAddress = builder.Configuration.GetValue<string>("GrpcService:Address") ?? "http://localhost:50051";
builder.Services.AddGrpcClient<TrafficRagInference.TrafficRagInferenceClient>(o =>
{
    o.Address = new Uri(grpcAddress);
}).ConfigureChannel(o => { o.MaxSendMessageSize = 20 * 1024 * 1024; o.MaxReceiveMessageSize = 2 * 1024 * 1024; });
builder.Services.AddScoped<IGrpcInferenceService, GrpcInferenceService>();

var app = builder.Build();

if (builder.Configuration.GetValue("Database:MigrateOnStartup", true))
{
    using var scope = app.Services.CreateScope();
    await scope.ServiceProvider.GetRequiredService<ChatAIWebDbContext>().Database.MigrateAsync();
    await scope.ServiceProvider.GetRequiredService<IAdminSeeder>().SeedAsync();
}

app.UseExceptionHandler();
app.UseStatusCodePages();

app.UseSwagger();
app.UseSwaggerUI();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapGet("/health/live", () => Results.Ok(new { status = "alive" }));
app.MapHealthChecks("/health/ready");
app.MapPrometheusScrapingEndpoint();

app.Run();

public partial class Program { }
