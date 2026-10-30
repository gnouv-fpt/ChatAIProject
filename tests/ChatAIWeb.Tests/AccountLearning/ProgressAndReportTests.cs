using BusinessLogic.DTOs.Requests;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Implementations;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessObject.Constants;
using BusinessObject.Entities;
using DataAccess;
using DataAccess.Repositories.Implementations;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace ChatAIWeb.Tests.AccountLearning;

[Collection(AccountLearningCollection.Name)]
public sealed class ProgressAndReportTests : IClassFixture<SqlServerDatabase>
{
    private readonly SqlServerDatabase database;

    public ProgressAndReportTests(SqlServerDatabase database) => this.database = database;

    private static LearningProgressService Progress(ChatAIWebDbContext db) =>
        new(new LearningProgressRepository(db),
            new LocalContentCatalogClient(new QuestionBankRepository(db), new GenericRepository<Question>(db), new GenericRepository<ExamTemplate>(db)),
            new QuestionBookmarkRepository(db));

    private static UsageReportService Reports(ChatAIWebDbContext db) =>
        new(new UsageReportRepository(db), new UserRepository(db),
            new QuotaService(new QuotaRepository(db), new UserRepository(db), new QuotaSettings(), NullLogger<QuotaService>.Instance));

    [Fact]
    public async Task ProgressCountsOnlyGradedAnswersOncePerQuestion()
    {
        var user = await database.AddUserAsync();
        var seed = new LearningSeed();
        await using (var setup = database.CreateContext())
        {
            await seed.AddBanksAsync(setup);
            await seed.AddAttemptsAsync(setup, user.Id);
        }

        await using var db = database.CreateContext();
        var progress = await Progress(db).GetBankProgressAsync(user.Id, seed.BankId);

        Assert.Equal(4, progress.TotalQuestions);
        Assert.Equal(3, progress.AnsweredQuestions);
        Assert.Equal(2, progress.CorrectQuestions);
        Assert.Equal(1, progress.WrongQuestions);
        Assert.Equal(1, progress.UnseenQuestions);
        Assert.Equal(5, progress.GradedAnswers);
        Assert.Equal(3, progress.CorrectAnswers);
        Assert.Equal(60.0, progress.AccuracyPercent);
        Assert.Equal(2, progress.PracticeAttempts);
        Assert.Equal(1, progress.CompletedExams);
        Assert.Equal(0, progress.PassedExams);
        Assert.Equal(1, progress.BestExamScore);
        var signs = Assert.Single(progress.Topics, t => t.Topic == "Biển báo");
        Assert.Equal((2, 2, 0), (signs.AnsweredQuestions, signs.CorrectQuestions, signs.WrongQuestions));
        var junction = Assert.Single(progress.Topics, t => t.Topic == "Sa hình");
        Assert.Equal((1, 0, 1), (junction.AnsweredQuestions, junction.CorrectQuestions, junction.WrongQuestions));

        var wrong = await Progress(db).GetWrongQuestionsAsync(user.Id, seed.BankId, 1, 20);
        Assert.Equal(seed.Questions[2], Assert.Single(wrong.Items).QuestionId);
        var unseen = await Progress(db).GetUnseenQuestionsAsync(user.Id, seed.BankId, 1, 20);
        Assert.Equal(seed.Questions[3], Assert.Single(unseen.Items).QuestionId);

        // Another user's attempts never leak into this user's progress.
        var other = await database.AddUserAsync();
        var empty = await Progress(db).GetBankProgressAsync(other.Id, seed.BankId);
        Assert.Equal(0, empty.AnsweredQuestions);
        Assert.Equal(4, empty.UnseenQuestions);
    }

    [Fact]
    public async Task HistoryIsPagedPerUserAndDraftBanksAreHidden()
    {
        var user = await database.AddUserAsync();
        var seed = new LearningSeed();
        await using (var setup = database.CreateContext())
        {
            await seed.AddBanksAsync(setup);
            await seed.AddAttemptsAsync(setup, user.Id);
        }

        await using var db = database.CreateContext();
        var page = await Progress(db).GetHistoryAsync(user.Id, seed.BankId, null, 1, 3);
        Assert.Equal(4, page.TotalCount);
        Assert.Equal(3, page.Items.Count);
        Assert.True(page.Items.Zip(page.Items.Skip(1)).All(p => p.First.StartedAt >= p.Second.StartedAt));
        // Bank names are resolved through the Content catalog, not a cross-database join.
        Assert.All(page.Items, item => Assert.Equal("Bộ đề thử nghiệm", item.BankName));

        var other = await database.AddUserAsync();
        Assert.Equal(0, (await Progress(db).GetHistoryAsync(other.Id, null, null, 1, 20)).TotalCount);
        await Assert.ThrowsAsync<NotFoundException>(() => Progress(db).GetBankProgressAsync(user.Id, seed.DraftBankId));
    }

    [Fact]
    public async Task BookmarksAreIdempotent()
    {
        var user = await database.AddUserAsync();
        var seed = new LearningSeed();
        await using (var setup = database.CreateContext())
        {
            await seed.AddBanksAsync(setup);
        }

        await using var db = database.CreateContext();
        var service = Progress(db);
        await service.AddBookmarkAsync(user.Id, seed.Questions[1]);
        await service.AddBookmarkAsync(user.Id, seed.Questions[1]);
        var bookmarks = await service.GetBookmarksAsync(user.Id, seed.BankId, 1, 20);
        Assert.Equal(1, bookmarks.TotalCount);
        Assert.Equal(2, Assert.Single(bookmarks.Items).Number);
        Assert.Equal(0, (await service.GetBookmarksAsync(user.Id, seed.DraftBankId, 1, 20)).TotalCount);
        Assert.Equal(1, (await service.GetBankProgressAsync(user.Id, seed.BankId)).BookmarkedQuestions);

        await service.RemoveBookmarkAsync(user.Id, seed.Questions[1]);
        await service.RemoveBookmarkAsync(user.Id, seed.Questions[1]);
        Assert.Equal(0, (await service.GetBookmarksAsync(user.Id, null, 1, 20)).TotalCount);
        await Assert.ThrowsAsync<NotFoundException>(() => service.AddBookmarkAsync(user.Id, Guid.NewGuid()));
    }

    [Fact]
    public async Task UsageCountsTurnsNotMessagesAndRespectsScope()
    {
        var alice = await database.AddUserAsync();
        var bob = await database.AddUserAsync();
        var aliceSession = await database.AddSessionAsync(alice.Id);
        var bobSession = await database.AddSessionAsync(bob.Id);

        // Legacy pair, durable completed pair, a failed and a processing turn for Alice; one turn for Bob.
        await database.AddUserPromptAsync(aliceSession);
        await database.AddTurnAsync(aliceSession, null, tokensUsed: 100);
        await database.AddUserPromptAsync(aliceSession);
        await database.AddTurnAsync(aliceSession, ChatTurnStates.Completed, tokensUsed: 200, isViolation: true, quotaSettledAt: DateTime.UtcNow);
        await database.AddTurnAsync(aliceSession, ChatTurnStates.Failed);
        await database.AddTurnAsync(aliceSession, ChatTurnStates.Processing, reservedTokens: 500, leaseExpiresAt: DateTime.UtcNow.AddMinutes(1));
        await database.AddUserPromptAsync(bobSession);
        await database.AddTurnAsync(bobSession, ChatTurnStates.Completed, tokensUsed: 50);

        await using var db = database.CreateContext();
        var mine = await Reports(db).GetUsageAsync(alice.Id, false, new UsageReportQueryDto());
        Assert.Equal("User", mine.Scope);
        Assert.Equal(2, mine.Totals.CompletedTurns);
        Assert.Equal(1, mine.Totals.FailedTurns);
        Assert.Equal(1, mine.Totals.ViolationTurns);
        Assert.Equal(300, mine.Totals.TokensUsed);
        Assert.Equal(200, mine.Totals.TokensSettled);
        Assert.Equal(30, mine.Daily.Count);
        Assert.Equal(2, mine.Daily[^1].CompletedTurns);
        Assert.Empty(mine.TopUsers);
        Assert.Equal(500, mine.Quota!.ReservedTokens);

        await Assert.ThrowsAsync<ForbiddenException>(() =>
            Reports(db).GetUsageAsync(alice.Id, false, new UsageReportQueryDto { UserId = bob.Id }));

        var admin = await database.AddUserAsync(role: BusinessObject.Enums.UserRole.Admin);
        var all = await Reports(db).GetUsageAsync(admin.Id, true, new UsageReportQueryDto());
        Assert.Equal("All", all.Scope);
        Assert.True(all.Totals.CompletedTurns >= 3);
        Assert.Contains(all.TopUsers, u => u.UserId == alice.Id && u.CompletedTurns == 2 && u.TokensUsed == 300);
        var bobOnly = await Reports(db).GetUsageAsync(admin.Id, true, new UsageReportQueryDto { UserId = bob.Id });
        Assert.Equal(1, bobOnly.Totals.CompletedTurns);

        var today = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(7));
        await Assert.ThrowsAsync<BadRequestException>(() =>
            Reports(db).GetUsageAsync(alice.Id, false, new UsageReportQueryDto { From = today, To = today.AddDays(-1) }));
    }
}
