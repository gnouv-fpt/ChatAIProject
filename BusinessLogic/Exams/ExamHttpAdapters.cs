using BusinessLogic.Infrastructure.Interfaces;
using System.Net.Http.Headers;
using System.Net;
using System.Net.Http.Json;
using BusinessLogic.Exams;
using BusinessLogic.Exceptions;
using Microsoft.Extensions.Configuration;

namespace BusinessLogic.Exams;

public sealed class ContentQuestionClient(HttpClient client, IConfiguration configuration, IJwtTokenService? tokens = null) : IExamQuestionSource
{
    public async Task<TemplateQuestionSet> GetTemplateAsync(string code, int version, CancellationToken cancellationToken)
    {
        var path = $"internal/content/exam-template-questions?code={Uri.EscapeDataString(code)}&version={version}";
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        if (tokens is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateContentServiceToken());
        else ExamHttpAuth.AddInternalKey(request, configuration);
        using var response = await SendContentAsync(request, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound)
            throw new BadRequestException("Không tìm thấy đề mẫu đã xuất bản.");
        await RequireContentSuccessAsync(response, cancellationToken);
        return await response.Content.ReadFromJsonAsync<TemplateQuestionSet>(cancellationToken)
            ?? throw new InvalidOperationException("Content service returned an empty template.");
    }

    public async Task<IReadOnlyList<BankQuestion>> GetQuestionsAsync(string categoryId, string bankVersion,
        int count, CancellationToken cancellationToken)
    {
        var path = configuration["Exams:ContentQuestionsPath"]
            ?? "internal/content/exam-questions";
        var uri = $"{path}?categoryId={Uri.EscapeDataString(categoryId)}&bankVersion={Uri.EscapeDataString(bankVersion)}&count={count}";
        using var request = new HttpRequestMessage(HttpMethod.Get, uri);
        if (tokens is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateContentServiceToken());
        else ExamHttpAuth.AddInternalKey(request, configuration);
        using var response = await SendContentAsync(request, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound)
            throw new BadRequestException("Không tìm thấy ngân hàng câu hỏi đã chọn.");
        await RequireContentSuccessAsync(response, cancellationToken);
        return await response.Content.ReadFromJsonAsync<List<BankQuestion>>(cancellationToken) ?? [];
    }

    private async Task<HttpResponseMessage> SendContentAsync(HttpRequestMessage request, CancellationToken ct)
    {
        try { return await client.SendAsync(request, ct); }
        catch (HttpRequestException) { throw new ServiceUnavailableException("Dịch vụ nội dung chưa sẵn sàng. Vui lòng thử lại."); }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested) { throw new UpstreamTimeoutException("Dịch vụ nội dung phản hồi quá chậm."); }
    }

    private static async Task RequireContentSuccessAsync(HttpResponseMessage response, CancellationToken ct)
    {
        if (response.IsSuccessStatusCode) return;
        if (response.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.Conflict)
        {
            var detail = "Thông số đề không phù hợp profile hoặc quy định đã hết phạm vi áp dụng.";
            try
            {
                var problem = await response.Content.ReadFromJsonAsync<System.Text.Json.JsonElement>(ct);
                if (problem.TryGetProperty("detail", out var value) && value.ValueKind == System.Text.Json.JsonValueKind.String &&
                    value.GetString() is { Length: > 0 and <= 2000 } message) detail = message;
            }
            catch (System.Text.Json.JsonException) { }
            if (response.StatusCode == HttpStatusCode.Conflict) throw new ConflictException(detail);
            throw new BadRequestException(detail);
        }
        throw new ServiceUnavailableException("Dịch vụ nội dung chưa sẵn sàng. Vui lòng thử lại.");
    }
}

public sealed class UserExamResultClient(HttpClient client, IConfiguration configuration, IJwtTokenService? tokens = null) : IExamResultSink
{
    public async Task SaveAsync(SaveExamResult result, CancellationToken cancellationToken)
    {
        var path = configuration["Exams:SaveResultPath"]
            ?? "internal/user/exam-results";
        using var request = new HttpRequestMessage(HttpMethod.Post, path)
        {
            Content = JsonContent.Create(result)
        };
        if (tokens is not null) request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateExamServiceToken());
        else ExamHttpAuth.AddInternalKey(request, configuration);
        using var response = await client.SendAsync(request, cancellationToken);
        if (response.StatusCode == HttpStatusCode.Conflict)
            throw new ConflictException("Lượt thi đã được lưu với nội dung khác.");
        response.EnsureSuccessStatusCode();
    }
}

internal static class ExamHttpAuth
{
    internal static void AddInternalKey(HttpRequestMessage request, IConfiguration configuration)
    {
        var value = configuration["Exams:InternalApiKey"];
        if (!string.IsNullOrWhiteSpace(value)) request.Headers.Add("X-Internal-Api-Key", value);
    }
}
