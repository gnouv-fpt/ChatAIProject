using System.Linq.Expressions;
using System.Text.Json;
using BusinessLogic.Exams;
using BusinessLogic.Exceptions;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Configuration;

namespace BusinessLogic.Tests;

public sealed class ExamAttemptReviewTests
{
    [Fact]
    public async Task Review_preserves_submitted_version_order_keys_assets_and_unanswered_questions()
    {
        var (service, attempt, snapshot) = Create();
        var review = await service.GetReviewAsync(attempt.UserId, attempt.Id, default);
        Assert.Equal(snapshot.BankId, review.BankId);
        Assert.Equal("2", review.BankVersion);
        Assert.Equal(snapshot.Questions.Select(q => q.QuestionId), review.Questions.Select(q => q.QuestionId));
        Assert.Equal("b", review.Questions[0].SelectedOptionId);
        Assert.Equal("b", review.Questions[0].CorrectOptionId);
        Assert.Equal("a", review.Questions[1].SelectedOptionId);
        Assert.Equal("b", review.Questions[1].CorrectOptionId);
        Assert.Null(review.Questions[2].SelectedOptionId);
        Assert.Equal("https://animations.example.org/q544.html", review.Questions[0].ExplanationAnimationUrl);
        Assert.Equal(snapshot.Questions[0].Assets, review.Questions[0].Assets);
        Assert.Equal("Saved explanation", review.Questions[0].Explanation);
        Assert.Equal(1, review.Correct);
        Assert.Equal(3, review.Total);
        Assert.False(review.IsPassed);
    }

    [Fact]
    public async Task Review_does_not_disclose_another_users_result_or_unknown_attempt()
    {
        var (service, attempt, _) = Create();
        await Assert.ThrowsAsync<NotFoundException>(() => service.GetReviewAsync(Guid.NewGuid(), attempt.Id, default));
        await Assert.ThrowsAsync<NotFoundException>(() => service.GetReviewAsync(attempt.UserId, Guid.NewGuid(), default));
    }

    [Theory]
    [InlineData("http://animations.example.org/q544.html")]
    [InlineData("https://animations.example.org.evil.test/q544.html")]
    [InlineData("https://animations.example.org/q544.html?answer=b")]
    [InlineData("javascript:alert(1)")]
    public async Task Review_omits_links_outside_current_host_policy(string url)
    {
        var (service, attempt, _) = Create(url);
        var review = await service.GetReviewAsync(attempt.UserId, attempt.Id, default);
        Assert.All(review.Questions, q => Assert.Null(q.ExplanationAnimationUrl));
    }

    private static (ExamResultService, ExamAttempt, SaveExamResult) Create(string url = "https://animations.example.org/q544.html")
    {
        var owner = Guid.NewGuid();
        var options = new ExamOption[] { new("b", "Second"), new("a", "First") };
        var questions = new[] { "b", "a", null }.Select(selected => new GradedQuestion(Guid.NewGuid().ToString(),
            "2", "Saved question", options, "b", selected, Assets: [new("original", "https://example.org/original.png",
                "Original image", new string('a', 64), "image/png")], Explanation: "Saved explanation", ExplanationAnimationUrl: url)).ToArray();
        var snapshot = new SaveExamResult(Guid.NewGuid(), Guid.NewGuid(), owner, "2", DateTimeOffset.UtcNow,
            1, 3, questions, Guid.NewGuid());
        var attempt = new ExamAttempt { Id = snapshot.AttemptId, UserId = owner, Score = 1, IsPassed = false,
            ExamSnapshotJson = JsonSerializer.Serialize(snapshot) };
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            { ["Content:AnimationAllowedHosts:0"] = "animations.example.org" }).Build();
        return (new ExamResultService(new Attempts(attempt), null!, configuration), attempt, snapshot);
    }

    private sealed class Attempts(ExamAttempt attempt) : IExamAttemptRepository
    {
        public Task<ExamAttempt?> GetOwnedAsync(Guid id, Guid user, CancellationToken ct) =>
            Task.FromResult(id == attempt.Id && user == attempt.UserId ? attempt : null);
        public Task<ExamAttempt> InsertOrGetAsync(ExamAttempt item, CancellationToken ct) => throw new NotSupportedException();
        public Task<IReadOnlyList<ExamAttempt>> GetHistoryAsync(Guid user, int page, int size, CancellationToken ct) => throw new NotSupportedException();
        public Task<ExamAttempt?> GetByIdAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<IReadOnlyList<ExamAttempt>> FindAsync(Expression<Func<ExamAttempt, bool>> predicate, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> AnyAsync(Expression<Func<ExamAttempt, bool>> predicate, CancellationToken ct = default) => throw new NotSupportedException();
        public Task AddAsync(ExamAttempt item, CancellationToken ct = default) => throw new NotSupportedException();
        public void Update(ExamAttempt item) => throw new NotSupportedException();
        public void Remove(ExamAttempt item) => throw new NotSupportedException();
        public Task<int> SaveChangesAsync(CancellationToken ct = default) => throw new NotSupportedException();
    }
}
