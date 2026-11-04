using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using DataAccess.Repositories.Implementations;
using Xunit;

namespace Content.Tests;

public sealed class ContentBankImportTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), "phuc-import-" + Guid.NewGuid().ToString("N"));
    private FileQuestionBankRepository Repository() => new(_root);
    private static AnimationSettings Settings() => new() { AllowedHosts = ["animations.example.org"] };

    [Fact]
    public async Task ReviewedMappingsRoundTripWithoutChangingTheSourceOrExposingAnswers()
    {
        var bank = QuestionBankTests.Fixture();
        var manifests = new ContentManifestService(Settings());
        var banks = new QuestionBankService(Repository(), Settings());
        var importer = new ContentBankImportService(manifests, banks);
        var mappings = new List<QuestionAnimationDto> { new(bank.Questions[0].Id, "https://animations.example.org/q1.html") };
        var reviewed = manifests.Preview(new() { Bank = bank, Animations = mappings });
        var request = new ImportQuestionBankRequestDto { Bank = bank, Animations = mappings, ExpectedManifestHash = reviewed.ManifestHash };
        var imported = await importer.ImportAsync(request, Guid.NewGuid());
        Assert.Null(bank.Questions[0].ExplanationAnimationUrl);
        Assert.Equal(mappings[0].ExplanationAnimationUrl, imported.Bank.Questions[0].ExplanationAnimationUrl);
        Assert.Equal(1, manifests.Preview(new() { Bank = imported.Bank }).AnimationCount);
        Assert.Equal(imported.Summary.Hash, (await importer.ImportAsync(request, Guid.NewGuid())).Summary.Hash);
        await banks.PublishAsync(bank.Id, bank.Version, new() { ExpectedHash = imported.Summary.Hash, SourceAndAnswersReviewed = true });
        var publicJson = System.Text.Json.JsonSerializer.Serialize(await banks.GetQuestionsAsync(bank.Id, bank.Version, null, null, null, 1, 20));
        Assert.DoesNotContain("Explanation", publicJson);
        Assert.DoesNotContain("CorrectOption", publicJson);
        Assert.DoesNotContain("q1.html", publicJson);
    }

    [Fact]
    public async Task ChangedManifestOrInvalidMappingCannotWriteDrafts()
    {
        var bank = QuestionBankTests.Fixture();
        var importer = new ContentBankImportService(new ContentManifestService(Settings()), new QuestionBankService(Repository(), Settings()));
        await Assert.ThrowsAsync<ConflictException>(() => importer.ImportAsync(new() {
            Bank = bank, ExpectedManifestHash = new string('0', 64) }, Guid.NewGuid()));
        await Assert.ThrowsAsync<BadRequestException>(() => importer.ImportAsync(new() {
            Bank = bank, Animations = [new(Guid.NewGuid(), "https://animations.example.org/q1.html")] }, Guid.NewGuid()));
        await Assert.ThrowsAsync<BadRequestException>(() => importer.ImportAsync(new() {
            Bank = bank, Animations = null! }, Guid.NewGuid()));
        Assert.Empty(await Repository().ListAsync());
    }

    [Fact]
    public void EmbeddedAnimationsAreCountedOnceAndConflictingMappingsAreRejected()
    {
        var fixture = QuestionBankTests.Fixture();
        var question = fixture.Questions[0] with { ExplanationAnimationUrl = "https://animations.example.org/q1.html" };
        var bank = fixture with { Questions = [question] };
        var manifests = new ContentManifestService(Settings());
        var embedded = manifests.Preview(new() { Bank = bank });
        Assert.True(embedded.CanImport); Assert.Equal(1, embedded.AnimationCount);
        Assert.Equal(1, manifests.Preview(new() { Bank = bank, Animations = [new(question.Id, question.ExplanationAnimationUrl)] }).AnimationCount);
        var conflict = manifests.Preview(new() { Bank = bank, Animations = [new(question.Id, "https://animations.example.org/other.html")] });
        Assert.False(conflict.CanImport); Assert.Null(conflict.ManifestHash);
    }

    [Fact]
    public async Task PublishRechecksAnimationPolicyAndLeavesRejectedDraftUnpublished()
    {
        var fixture = QuestionBankTests.Fixture();
        var bank = fixture with { Questions = [fixture.Questions[0] with { ExplanationAnimationUrl = "https://animations.example.org/q1.html" }] };
        var imported = await new QuestionBankService(Repository(), Settings()).ImportAsync(bank, Guid.NewGuid());
        var restricted = new QuestionBankService(Repository(), new AnimationSettings());
        Assert.NotEmpty((await restricted.PreviewAsync(bank.Id, bank.Version)).Errors);
        await Assert.ThrowsAsync<BadRequestException>(() => restricted.PublishAsync(bank.Id, bank.Version,
            new() { ExpectedHash = imported.Summary.Hash, SourceAndAnswersReviewed = true }));
        Assert.False((await Repository().GetAsync(bank.Id, bank.Version))!.IsPublished);
    }

    public void Dispose() { if (Directory.Exists(_root)) Directory.Delete(_root, true); }
}
