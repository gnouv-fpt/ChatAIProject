using System.Text.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Implementations;
using BusinessObject.Entities;
using DataAccess.Repositories.Implementations;
using Xunit;

namespace Content.Tests;

public sealed class QuestionBankTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "content-tests-" + Guid.NewGuid().ToString("N"));
    private QuestionBankService Service() => new(new FileQuestionBankRepository(_directory));
    public static QuestionBank Fixture() => new()
    {
        Id = Guid.NewGuid(), Version = "fixture-1", Title = "TEST FIXTURE - không dùng demo",
        SourceUrl = "https://example.org/bank", SourceDescription = "Dữ liệu kiểm thử tổng hợp, không phải nguồn chính thức",
        Profile = new() { Id = "test", Version = "1", SourceUrl = "https://example.org/profile", QuestionCount = 1, DurationSeconds = 30, PassCount = 1 },
        Questions = [new() { Id = Guid.NewGuid(), Number = 1, Topic = "test", Text = "Câu thử?", Explanation = "Giải thích bí mật",
            SourceUrl = "https://example.org/question", Options = [new("a", "Một"), new("b", "Hai")], CorrectOptionIds = ["a"] }]
    };

    [Fact]
    public async Task DraftIsHiddenAndPublishRequiresExactReviewedHash()
    {
        var service = Service(); var bank = Fixture();
        var draft = await service.ImportAsync(bank, Guid.NewGuid());
        Assert.Empty(await service.ListAsync(false));
        await Assert.ThrowsAsync<NotFoundException>(() => service.GetQuestionsAsync(bank.Id, bank.Version, null, null, null, 1, 20));
        await Assert.ThrowsAsync<BadRequestException>(() => service.PublishAsync(bank.Id, bank.Version, new() { ExpectedHash = draft.Summary.Hash }));
        await Assert.ThrowsAsync<ConflictException>(() => service.PublishAsync(bank.Id, bank.Version, new() { ExpectedHash = new string('0', 64), SourceAndAnswersReviewed = true }));
        await service.PublishAsync(bank.Id, bank.Version, new() { ExpectedHash = draft.Summary.Hash, SourceAndAnswersReviewed = true });
        Assert.Single(await Service().ListAsync(false)); // restart reads durable publication
        var result = await service.GetQuestionsAsync(bank.Id, bank.Version, null, 1, 1, 1, 10);
        var json = JsonSerializer.Serialize(result);
        Assert.DoesNotContain("CorrectOptionIds", json);
        Assert.DoesNotContain("Explanation", json);
        Assert.DoesNotContain("Giải thích bí mật", json);
    }

    [Fact]
    public async Task ConcurrentImportsNeverOverwriteVersion()
    {
        var bank = Fixture();
        var results = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Service().ImportAsync(bank, Guid.NewGuid())));
        Assert.Single(results.Select(r => r.Summary.Hash).Distinct());
        await Assert.ThrowsAsync<ConflictException>(() => Service().ImportAsync(bank with { Title = "changed" }, Guid.NewGuid()));
        Assert.Equal(bank.Title, (await Service().PreviewAsync(bank.Id, bank.Version)).Bank.Title);
    }

    [Fact]
    public async Task ConcurrentPublicationIsIdempotent()
    {
        var bank = Fixture(); var draft = await Service().ImportAsync(bank, Guid.NewGuid());
        await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Service().PublishAsync(bank.Id, bank.Version,
            new() { ExpectedHash = draft.Summary.Hash, SourceAndAnswersReviewed = true })));
        Assert.Single(await Service().ListAsync(false));
    }

    [Fact]
    public async Task InvalidKeysSourcesProfilesAndPathTraversalAreRejected()
    {
        var bank = Fixture();
        Assert.NotEmpty(QuestionBankService.Validate(bank with { Questions = [bank.Questions[0] with { CorrectOptionIds = ["missing"] }] }));
        Assert.NotEmpty(QuestionBankService.Validate(bank with { Profile = bank.Profile with { QuestionCount = 2 } }));
        Assert.NotEmpty(QuestionBankService.Validate(bank with { SourceUrl = "http://example.org" }));
        Assert.NotEmpty(QuestionBankService.Validate(bank with { Questions = [bank.Questions[0], bank.Questions[0]] }));
        Assert.NotEmpty(QuestionBankService.Validate(bank with { Questions = [bank.Questions[0] with {
            AllowOptionShuffle = true, Options = [new("a", "Tất cả phương án trên"), new("b", "Hai")] }] }));
        await Assert.ThrowsAsync<BadRequestException>(() => Service().PreviewAsync(bank.Id, "../../outside"));
    }

    [Fact]
    public async Task TopicRangeAndPagingAreAppliedBeforeProjection()
    {
        var bank = Fixture(); var q = bank.Questions[0];
        bank = bank with { Questions = [q, q with { Id = Guid.NewGuid(), Number = 2, Topic = "other" }] };
        var preview = await Service().ImportAsync(bank, Guid.NewGuid());
        await Service().PublishAsync(bank.Id, bank.Version, new() { ExpectedHash = preview.Summary.Hash, SourceAndAnswersReviewed = true });
        var result = await Service().GetQuestionsAsync(bank.Id, bank.Version, "other", 1, 2, 1, 1);
        Assert.Equal(1, result.TotalCount); Assert.Equal(2, Assert.Single(result.Items).Number);
    }
    public void Dispose() { if (Directory.Exists(_directory)) Directory.Delete(_directory, true); }
}
