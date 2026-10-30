using System.Net.Http.Headers;
using System.Net.Http.Json;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed record LearningCatalogSnapshot(IReadOnlyList<CatalogBank> Banks, IReadOnlyList<CatalogQuestion> Questions);

public sealed class LearningCatalogService(IContentBankRepository banks)
{
    public async Task<LearningCatalogSnapshot> GetAsync(CancellationToken ct)
    {
        var packages = (await banks.ListAsync(ct)).Where(b => b.IsPublished)
            .GroupBy(b => b.Bank.Id).Select(g => g.MaxBy(b => int.Parse(b.Bank.Version))!).ToList();
        return new(packages.Select(p => new CatalogBank(p.Bank.Id, p.Bank.Id.ToString("N"), p.Bank.Title,
                int.Parse(p.Bank.Version), null, QuestionBankStatus.Published)).ToList(),
            packages.SelectMany(p => p.Bank.Questions.Select(q => new CatalogQuestion(q.Id, p.Bank.Id, q.Number,
                q.Topic, q.IsCritical, q.Assets.Count > 0, q.Text))).ToList());
    }
}

public sealed class LearningCatalogHttpClient(HttpClient http, IJwtTokenService tokens) : ILearningCatalogClient
{
    private static readonly System.Text.Json.JsonSerializerOptions JsonOptions = new(System.Text.Json.JsonSerializerDefaults.Web)
    { Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter() } };
    private async Task<LearningCatalogSnapshot> GetAsync(CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, "internal/content/learning-catalog");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", tokens.CreateContentServiceToken());
        try
        {
            using var response = await http.SendAsync(request, ct);
            if (!response.IsSuccessStatusCode) throw new ServiceUnavailableException("Không thể đọc danh mục nội dung.");
            return await response.Content.ReadFromJsonAsync<LearningCatalogSnapshot>(JsonOptions, ct)
                ?? throw new ServiceUnavailableException("Danh mục nội dung không hợp lệ.");
        }
        catch (Exception ex) when (ex is HttpRequestException or System.Text.Json.JsonException || ex is OperationCanceledException && !ct.IsCancellationRequested)
        { throw new ServiceUnavailableException("Dịch vụ nội dung chưa sẵn sàng."); }
    }
    public async Task<IReadOnlyList<CatalogBank>> GetPublishedBanksAsync(CancellationToken cancellationToken = default) => (await GetAsync(cancellationToken)).Banks;
    public async Task<CatalogBank?> GetBankAsync(Guid bankId, CancellationToken cancellationToken = default) =>
        (await GetAsync(cancellationToken)).Banks.SingleOrDefault(b => b.Id == bankId);
    public async Task<IReadOnlyList<CatalogBank>> GetBanksByIdsAsync(IReadOnlyCollection<Guid> bankIds, CancellationToken cancellationToken = default) =>
        bankIds.Count == 0 ? [] : (await GetAsync(cancellationToken)).Banks.Where(b => bankIds.Contains(b.Id)).ToList();
    public async Task<IReadOnlyList<CatalogQuestion>> GetQuestionsAsync(Guid bankId, CancellationToken cancellationToken = default) =>
        (await GetAsync(cancellationToken)).Questions.Where(q => q.BankId == bankId).ToList();
    public async Task<IReadOnlyList<CatalogQuestion>> GetQuestionsByIdsAsync(IReadOnlyCollection<Guid> questionIds, CancellationToken cancellationToken = default) =>
        questionIds.Count == 0 ? [] : (await GetAsync(cancellationToken)).Questions.Where(q => questionIds.Contains(q.Id)).ToList();
    public Task<IReadOnlyDictionary<Guid, string>> GetExamTemplateNamesAsync(IReadOnlyCollection<Guid> templateIds, CancellationToken cancellationToken = default) =>
        templateIds.Count == 0 ? Task.FromResult<IReadOnlyDictionary<Guid, string>>(new Dictionary<Guid, string>()) :
        throw new ServiceUnavailableException("Chưa nối danh mục đề mẫu.");
}
