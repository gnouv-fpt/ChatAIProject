using System.Net.Http.Headers;
using System.Net.Http.Json;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class ContentMaintenanceHttpClient(HttpClient http, IJwtTokenService tokens) : IContentMaintenanceService
{
    public async Task<ContentMaintenanceResult> RunAsync(CancellationToken cancellationToken = default)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "internal/content/maintenance");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateContentMaintenanceToken());
        using var response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<ContentMaintenanceResult>(cancellationToken)
            ?? throw new InvalidOperationException("Content maintenance returned no result.");
    }
}
