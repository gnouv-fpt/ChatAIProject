using System.Net.Http.Headers;
using System.Net.Http.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;

namespace BusinessLogic.Services.Implementations;

public sealed class ContentCatalogClient(HttpClient http, IJwtTokenService tokens) : IContentCatalogClient
{
    private static readonly System.Text.Json.JsonSerializerOptions JsonOptions = new(System.Text.Json.JsonSerializerDefaults.Web)
    {
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter() }
    };
    public async Task<List<DocumentChunk>> GetChunksAsync(Guid[] ids, CancellationToken ct)
    {
        if (ids.Length == 0) return [];
        if (ids.Length > 50) throw new ServiceUnavailableException("Phản hồi AI có quá nhiều trích dẫn.");
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "internal/content/chunks");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateContentServiceToken());
            request.Content = JsonContent.Create(ids);
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
                throw new ServiceUnavailableException("Không thể kiểm tra căn cứ từ dịch vụ nội dung.");
            var chunks = await response.Content.ReadFromJsonAsync<List<ContentChunkSnapshotDto>>(JsonOptions, ct)
                ?? throw new ServiceUnavailableException("Dịch vụ nội dung trả dữ liệu không hợp lệ.");
            return chunks.Select(c => c.ToEntity()).ToList();
        }
        catch (Exception ex) when (ex is HttpRequestException or System.Text.Json.JsonException ||
            ex is OperationCanceledException && !ct.IsCancellationRequested)
        {
            throw new ServiceUnavailableException("Dịch vụ nội dung chưa sẵn sàng.");
        }
    }

    public async Task<ScenarioAnswerDto?> ResolveScenarioAsync(int? number,
        IReadOnlyList<string> imageHashes, CancellationToken ct)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "internal/content/scenario-answer");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateContentServiceToken());
            request.Content = JsonContent.Create(new { number, imageHashes });
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode)
                throw new ServiceUnavailableException("Không thể tra cứu bộ câu hỏi sa hình.");
            if (response.StatusCode == System.Net.HttpStatusCode.NoContent)
                return null;
            return await response.Content.ReadFromJsonAsync<ScenarioAnswerDto>(JsonOptions, ct);
        }
        catch (Exception ex) when (ex is HttpRequestException or System.Text.Json.JsonException ||
            ex is OperationCanceledException && !ct.IsCancellationRequested)
        {
            throw new ServiceUnavailableException("Dịch vụ nội dung chưa sẵn sàng.");
        }
    }
}
