using System.Diagnostics;
using Microsoft.AspNetCore.Routing;

namespace Presentation.Infrastructure;

public sealed class RequestTelemetryMiddleware(RequestDelegate next, ILogger<RequestTelemetryMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Path == "/metrics")
        {
            await next(context);
            return;
        }
        var started = Stopwatch.GetTimestamp();
        var status = 500;
        try
        {
            await next(context);
            status = context.Response.StatusCode;
        }
        finally
        {
            var route = (context.GetEndpoint() as RouteEndpoint)?.RoutePattern.RawText ?? "unmatched";
            logger.LogInformation("HTTP {Method} {Route} {Status} {DurationMs}",
                context.Request.Method, route, status, Stopwatch.GetElapsedTime(started).TotalMilliseconds);
        }
    }
}
