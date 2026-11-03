using BusinessLogic.DTOs;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using Xunit;

namespace Content.Tests;

public sealed class ContentManifestTests
{
    private readonly ContentManifestService _service = new(new AnimationSettings { AllowedHosts = ["animations.example.org"] });

    [Theory]
    [InlineData("http://localhost:8765/q544.html", true)]
    [InlineData("http://localhost:8766/q544.html", false)]
    [InlineData("http://localhost.evil.test:8765/q544.html", false)]
    [InlineData("http://127.0.0.1:8765/q544.html", false)]
    [InlineData("http://localhost:8765/q544.html?answer=1", false)]
    [InlineData("http://localhost:8765/%2e%2e/q544.html", false)]
    public void LocalAssetsRequireExactServerOriginAndRemainDisabledByDefault(string url, bool expected)
    {
        Assert.False(ContentManifestService.IsAllowedAnimationUrl(url, []));
        Assert.Equal(expected, ContentManifestService.IsAllowedAnimationUrl(url, [], "http://localhost:8765"));
        Assert.False(ContentManifestService.IsAllowedAnimationUrl(url, [], "http://example.org:8765"));
    }

    [Fact]
    public void LocalBankImagesAndAnimationsRequireExplicitDevelopmentSettings()
    {
        var bank = QuestionBankTests.Fixture();
        bank = bank with { Questions = [bank.Questions[0] with {
            Assets = [new("image", "http://localhost:8765/bank-review/544/image-1.jpeg", new string('a', 64), "image/jpeg", "Local original")],
            ExplanationAnimationUrl = "http://localhost:8765/q544.html"
        }] };
        Assert.NotEmpty(QuestionBankService.Validate(bank));
        Assert.Empty(QuestionBankService.Validate(bank, "http://localhost:8765"));
        Assert.False(new ContentManifestService(new()).Preview(new() { Bank = bank }).CanImport);
        Assert.True(new ContentManifestService(new() { LocalAssetOrigin = "http://localhost:8765" }).Preview(new() { Bank = bank }).CanImport);
    }

    [Theory]
    [InlineData("https://animations.example.org/lesson.html", true)]
    [InlineData("https://animations.example.org/lesson/", true)]
    [InlineData("http://animations.example.org/lesson.html", false)]
    [InlineData("javascript:alert(1)", false)]
    [InlineData("https://animations.example.org.evil.org/lesson.html", false)]
    [InlineData("https://user:password@animations.example.org/lesson.html", false)]
    [InlineData("https://animations.example.org:8443/lesson.html", false)]
    [InlineData("https://animations.example.org/lesson.html?answer=a", false)]
    [InlineData("https://animations.example.org/lesson.html#answer=a", false)]
    [InlineData("https://animations.example.org/../lesson.html", false)]
    [InlineData("https://animations.example.org/%2e%2e/lesson.html", false)]
    [InlineData("https://animations.example.org/%252e%252e/lesson.html", false)]
    [InlineData("https://animations.example.org/%0a/lesson.html", false)]
    [InlineData("https://animations.example.org\\lesson.html", false)]
    [InlineData("https://animations.example.org/image.svg", false)]
    public void AnimationUrlsAreExplicitAndDoNotCarryAnswerParameters(string url, bool allowed) =>
        Assert.Equal(allowed, ContentManifestService.IsAllowedAnimationUrl(url, ["animations.example.org"]));

    [Fact]
    public void AnimationNeedsServerConfiguredHostAndQuestionInSameVersion()
    {
        var bank = QuestionBankTests.Fixture();
        var request = new ContentManifestRequestDto { Bank = bank, Animations = [new(bank.Questions[0].Id, "https://animations.example.org/lesson.html")] };
        var valid = _service.Preview(request);
        Assert.True(valid.CanImport);
        Assert.NotNull(valid.ManifestHash);
        Assert.Equal(valid.ManifestHash, _service.Preview(request).ManifestHash);
        Assert.False(new ContentManifestService(new()).Preview(request).CanImport);
        request.Animations = [new(Guid.NewGuid(), "https://animations.example.org/lesson.html")];
        Assert.Contains(_service.Preview(request).Issues, i => i.Path.EndsWith("questionId"));
    }

    [Fact]
    public void ChangingAnimationChangesReviewedManifestHashAndDuplicateMappingsAreRejected()
    {
        var bank = QuestionBankTests.Fixture();
        var request = new ContentManifestRequestDto { Bank = bank, Animations = [new(bank.Questions[0].Id, "https://animations.example.org/one.html")] };
        var first = _service.Preview(request);
        request.Animations = [new(bank.Questions[0].Id, "https://animations.example.org/two.html")];
        Assert.NotEqual(first.ManifestHash, _service.Preview(request).ManifestHash);
        request.Animations.Add(request.Animations[0]);
        var invalid = _service.Preview(request);
        Assert.False(invalid.CanImport); Assert.Null(invalid.ManifestHash);
    }

    [Fact]
    public void InvalidNestedDataIsDiagnosedWithoutPersistence()
    {
        var bank = QuestionBankTests.Fixture();
        var invalid = _service.Preview(new() { Bank = bank with { Questions = [bank.Questions[0] with { CorrectOptionIds = ["unknown"] }] } });
        Assert.False(invalid.CanImport);
        Assert.Null(invalid.ManifestHash);
        Assert.Contains(invalid.Issues, i => i.Path == "bank");
        Assert.False(_service.Preview(new() { Bank = null! }).CanImport);
        Assert.False(_service.Preview(new() { Bank = bank, Animations = null! }).CanImport);
        Assert.True(_service.GetCapabilities().CanPersistBank);
        Assert.Equal("SqlContentAdapter", _service.GetCapabilities().PersistenceStatus);
    }
}
