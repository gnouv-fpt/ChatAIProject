using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Middleware;

// Makes 401/403 from the JWT handler return the same ProblemDetails shape as other API errors.
public static class JwtProblemDetailsEvents
{
    public static JwtBearerEvents Create()
    {
        return new JwtBearerEvents
        {
            OnChallenge = async context =>
            {
                context.HandleResponse();
                await WriteAsync(context.HttpContext, StatusCodes.Status401Unauthorized,
                    "Bạn cần đăng nhập hoặc access token đã hết hạn.");
            },
            OnForbidden = context =>
                WriteAsync(context.HttpContext, StatusCodes.Status403Forbidden,
                    "Bạn không có quyền thực hiện thao tác này.")
        };
    }

    private static async Task WriteAsync(HttpContext httpContext, int statusCode, string detail)
    {
        httpContext.Response.StatusCode = statusCode;
        var problemDetailsService = httpContext.RequestServices.GetRequiredService<IProblemDetailsService>();
        await problemDetailsService.WriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            ProblemDetails = new ProblemDetails { Status = statusCode, Detail = detail }
        });
    }
}
