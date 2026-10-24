using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddProblemDetails();
builder.Services.AddReverseProxy().LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = 429;
    options.AddPolicy("public", context => RateLimitPartition.GetFixedWindowLimiter(
        (context.Connection.RemoteIpAddress?.ToString() ?? "unknown") + (context.Request.Path.StartsWithSegments("/api/auth") ? ":auth" : ":api"),
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = context.Request.Path.StartsWithSegments("/api/auth") ? 10 : 60,
            Window = TimeSpan.FromMinutes(1), QueueLimit = 0, AutoReplenishment = true
        }));
    options.OnRejected = async (context, ct) =>
    {
        context.HttpContext.Response.Headers.RetryAfter = "60";
        await Results.Problem(statusCode: 429, detail: "Bạn gửi quá nhiều yêu cầu. Vui lòng thử lại sau.")
            .ExecuteAsync(context.HttpContext);
    };
});
builder.Services.AddOpenTelemetry().ConfigureResource(r => r.AddService("api-gateway"))
    .WithTracing(t => t.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation().AddOtlpExporter())
    .WithMetrics(m => m.AddAspNetCoreInstrumentation().AddHttpClientInstrumentation().AddPrometheusExporter());
builder.Logging.AddProvider(new Presentation.Infrastructure.SafeFileLoggerProvider(
    builder.Configuration["Logging:FilePath"] ?? "logs/gateway.jsonl"));
builder.WebHost.ConfigureKestrel(k => k.Limits.MaxRequestBodySize = 6 * 1024 * 1024);
var app = builder.Build();
app.UseExceptionHandler();
app.UseRateLimiter();
app.Use(async (context, next) =>
{
    context.Response.Headers.XContentTypeOptions = "nosniff";
    context.Response.Headers["Referrer-Policy"] = "no-referrer";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    await next();
});
app.MapGet("/health/live", () => Results.Ok(new { status = "alive" }));
app.MapPrometheusScrapingEndpoint();
app.MapReverseProxy();
app.Run();
public partial class Program { }
