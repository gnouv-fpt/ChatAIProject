using System.Net;
using System.Net.Http.Json;
using BusinessLogic.Exams;
using BusinessLogic.Exceptions;
using Microsoft.Extensions.Configuration;

namespace BusinessLogic.Exams;

public sealed class ContentQuestionClient(HttpClient client, IConfiguration configuration) : IExamQuestionSource
{
    public async Task<IReadOnlyList<BankQuestion>> GetQuestionsAsync(string categoryId, string bankVersion,
        int count, CancellationToken cancellationToken)
    {
        var path = configuration["Exams:ContentQuestionsPath"]
            ?? throw new InvalidOperationException("Exams:ContentQuestionsPath is required.");
        var uri = $"{path}?categoryId={Uri.EscapeDataString(categoryId)}&bankVersion={Uri.EscapeDataString(bankVersion)}&count={count}";
        using var request = new HttpRequestMessage(HttpMethod.Get, uri);
        ExamHttpAuth.AddInternalKey(request, configuration);
        using var response = await client.SendAsync(request, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound)
            throw new BadRequestException("Không tìm thấy ngân hàng câu hỏi đã chọn.");
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<List<BankQuestion>>(cancellationToken) ?? [];
    }
}

public sealed class UserExamResultClient(HttpClient client, IConfiguration configuration) : IExamResultSink
{
    public async Task SaveAsync(SaveExamResult result, CancellationToken cancellationToken)
    {
        var path = configuration["Exams:SaveResultPath"]
            ?? throw new InvalidOperationException("Exams:SaveResultPath is required.");
        using var request = new HttpRequestMessage(HttpMethod.Post, path)
        {
            Content = JsonContent.Create(result)
        };
        ExamHttpAuth.AddInternalKey(request, configuration);
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
