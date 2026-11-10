using System.Security.Cryptography;
using System.Text.Json;
using BusinessLogic.Services.Implementations;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Xunit;

namespace Content.Tests;

public sealed class ScenarioAnswerTests
{
    [Fact]
    public async Task PublishedSourceResolvesEveryScenarioAndRejectsConflictingImage()
    {
        var path = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../",
            "content-bank/csgt-2025-B-current/package.json"));
        using var source = JsonDocument.Parse(await File.ReadAllTextAsync(path));
        var bank = source.RootElement.GetProperty("bank").Deserialize<ContentBank>(
            new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        var hash = Convert.ToHexString(SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(bank)));
        var service = new QuestionBankService(new SourceBankRepository(
            new QuestionBankPackage(bank, hash, DateTime.UtcNow, Guid.Empty, true)));
        var imageCounts = bank.Questions.Where(q => q.Number is >= 486 and <= 600)
            .SelectMany(q => q.Assets.Select(asset => asset.Sha256))
            .GroupBy(value => value).ToDictionary(group => group.Key, group => group.Count());
        foreach (var question in bank.Questions.Where(q => q.Number is >= 486 and <= 600))
        {
            var byNumber = await service.ResolveScenarioAsync(question.Number, []);
            Assert.NotNull(byNumber);
            Assert.Equal(question.CorrectOptionIds, byNumber.CorrectOptionIds);
            Assert.Equal(question.SourceUrl, byNumber.SourceUrl);
            var byImage = await service.ResolveScenarioAsync(null, [question.Assets[0].Sha256]);
            if (imageCounts[question.Assets[0].Sha256] == 1)
                Assert.Equal(question.Number, byImage?.Number);
            else Assert.Null(byImage);
        }
        Assert.Null(await service.ResolveScenarioAsync(486, [bank.Questions[486].Assets[0].Sha256]));
    }

    private sealed class SourceBankRepository(QuestionBankPackage package) : IContentBankRepository
    {
        public Task<QuestionBankPackage?> GetAsync(Guid id, string version, CancellationToken ct = default) =>
            Task.FromResult(id == package.Bank.Id && version == package.Bank.Version ? package : null);
        public Task<IReadOnlyList<QuestionBankPackage>> ListAsync(CancellationToken ct = default) =>
            Task.FromResult<IReadOnlyList<QuestionBankPackage>>([package]);
        public Task<bool> AddAsync(QuestionBankPackage value, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<bool> PublishAsync(Guid id, string version, string expectedHash, CancellationToken ct = default) =>
            throw new NotSupportedException();
    }
}
