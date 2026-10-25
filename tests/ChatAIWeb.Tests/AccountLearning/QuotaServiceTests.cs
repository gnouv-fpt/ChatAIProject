using BusinessLogic.DTOs.Responses;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessObject.Constants;
using DataAccess;
using DataAccess.Repositories.Implementations;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace ChatAIWeb.Tests.AccountLearning;

[Collection(AccountLearningCollection.Name)]
public sealed class QuotaServiceTests : IClassFixture<SqlServerDatabase>
{
    private readonly SqlServerDatabase database;
    private readonly QuotaSettings settings = new() { LeaseGraceSeconds = 30, SettleCompletedAfterMinutes = 15 };

    public QuotaServiceTests(SqlServerDatabase database) => this.database = database;

    private static QuotaService Service(ChatAIWebDbContext db, QuotaSettings settings) =>
        new(new QuotaRepository(db), new UserRepository(db), settings, NullLogger<QuotaService>.Instance);

    private async Task<int> BalanceAsync(Guid userId)
    {
        await using var db = database.CreateContext();
        return (await db.Users.FindAsync(userId))!.TokenBalance;
    }

    [Fact]
    public async Task SettleSameEventTwiceChargesOnce()
    {
        var user = await database.AddUserAsync(10_000);
        var session = await database.AddSessionAsync(user.Id);
        var turn = await database.AddTurnAsync(session, ChatTurnStates.Completed, reservedTokens: 700, tokensUsed: 700);

        await using var db = database.CreateContext();
        var first = await Service(db, settings).SettleAsync(turn.Id, turn.Id);
        var replay = await Service(db, settings).SettleAsync(turn.Id, turn.Id);

        Assert.Equal(QuotaSettlementStatus.Settled, first.Status);
        Assert.Equal(700, first.TokensCharged);
        Assert.Equal(QuotaSettlementStatus.AlreadySettled, replay.Status);
        Assert.Equal(9_300, await BalanceAsync(user.Id));
    }

    [Fact]
    public async Task ConcurrentSettlesOfOneEventChargeOnce()
    {
        var user = await database.AddUserAsync(10_000);
        var session = await database.AddSessionAsync(user.Id);
        var turn = await database.AddTurnAsync(session, ChatTurnStates.Completed, reservedTokens: 900, tokensUsed: 900);

        var contexts = Enumerable.Range(0, 6).Select(_ => database.CreateContext()).ToList();
        var results = await Task.WhenAll(contexts.Select(db => Service(db, settings).SettleAsync(turn.Id, turn.Id)));
        foreach (var db in contexts)
        {
            await db.DisposeAsync();
        }

        Assert.Single(results, r => r.Status == QuotaSettlementStatus.Settled);
        Assert.Equal(5, results.Count(r => r.Status == QuotaSettlementStatus.AlreadySettled));
        Assert.Equal(9_100, await BalanceAsync(user.Id));
    }

    [Fact]
    public async Task ConcurrentReservesNeverExceedBalance()
    {
        var user = await database.AddUserAsync(5_000);
        var session = await database.AddSessionAsync(user.Id);
        var turns = new List<Guid>();
        for (var i = 0; i < 5; i++)
        {
            turns.Add((await database.AddTurnAsync(session, ChatTurnStates.Processing)).Id);
        }

        var contexts = turns.Select(_ => database.CreateContext()).ToList();
        var attempts = turns.Select(async (turnId, i) =>
        {
            try
            {
                return await Service(contexts[i], settings).ReserveAsync(user.Id, turnId, 2_000, TimeSpan.FromMinutes(2));
            }
            catch (QuotaExceededException)
            {
                return -1;
            }
        });
        var reserved = await Task.WhenAll(attempts);
        foreach (var db in contexts)
        {
            await db.DisposeAsync();
        }

        Assert.Equal(5_000, reserved.Where(r => r > 0).Sum());
        Assert.Equal(2, reserved.Count(r => r < 0));
        await using var check = database.CreateContext();
        var snapshot = await Service(check, settings).GetSnapshotAsync(user.Id);
        Assert.Equal(0, snapshot.AvailableTokens);
        Assert.Equal(5_000, snapshot.TokenBalance);
    }

    [Fact]
    public async Task ReleaseIsFencedByLeaseAndReturnsBudget()
    {
        var user = await database.AddUserAsync(3_000);
        var session = await database.AddSessionAsync(user.Id);
        var leaseId = Guid.NewGuid();
        var turn = await database.AddTurnAsync(session, ChatTurnStates.Processing, leaseId: leaseId);

        await using var db = database.CreateContext();
        var service = Service(db, settings);
        Assert.Equal(2_000, await service.ReserveAsync(user.Id, turn.Id, 2_000, TimeSpan.FromMinutes(1)));
        Assert.Equal(1_000, (await service.GetSnapshotAsync(user.Id)).AvailableTokens);

        Assert.False(await service.ReleaseAsync(turn.Id, Guid.NewGuid()));
        Assert.True(await service.ReleaseAsync(turn.Id, leaseId));
        Assert.False(await service.ReleaseAsync(turn.Id, leaseId));
        Assert.Equal(3_000, (await service.GetSnapshotAsync(user.Id)).AvailableTokens);
        Assert.Equal(3_000, await BalanceAsync(user.Id));
    }

    [Fact]
    public async Task ExpiredLeaseDoesNotHoldBudgetAndRecoveryReleasesIt()
    {
        var user = await database.AddUserAsync(4_000);
        var session = await database.AddSessionAsync(user.Id);
        var stale = await database.AddTurnAsync(session, ChatTurnStates.Processing, reservedTokens: 4_000,
            leaseExpiresAt: DateTime.UtcNow.AddMinutes(-5));

        await using var db = database.CreateContext();
        var service = Service(db, settings);
        Assert.Equal(4_000, (await service.GetSnapshotAsync(user.Id)).AvailableTokens);

        var result = await service.RecoverAsync();

        Assert.True(result.ExpiredReservationsReleased >= 1);
        await using var check = database.CreateContext();
        var turn = await check.ChatMessages.FindAsync(stale.Id);
        Assert.Equal(ChatTurnStates.Failed, turn!.TurnState);
        Assert.Equal(ChatResultStatuses.UsageUnknown, turn.ResultStatus);
        Assert.Equal(0, turn.ReservedTokens);
        Assert.Equal(4_000, await BalanceAsync(user.Id));
    }

    [Fact]
    public async Task RecoveryChargesUnknownUsageOnlyWhenConfigured()
    {
        var user = await database.AddUserAsync(4_000);
        var session = await database.AddSessionAsync(user.Id);
        var stale = await database.AddTurnAsync(session, ChatTurnStates.Processing, reservedTokens: 1_500,
            leaseExpiresAt: DateTime.UtcNow.AddMinutes(-5));

        await using var db = database.CreateContext();
        var charging = new QuotaSettings { ChargeReservationWhenUsageUnknown = true };
        await Service(db, charging).RecoverAsync();

        await using var check = database.CreateContext();
        Assert.NotNull((await check.ChatMessages.FindAsync(stale.Id))!.QuotaSettledAt);
        Assert.Equal(2_500, await BalanceAsync(user.Id));
    }

    [Fact]
    public async Task RecoverySettlesCompletedTurnWhoseEventNeverArrived()
    {
        var user = await database.AddUserAsync(10_000);
        var session = await database.AddSessionAsync(user.Id);
        var old = await database.AddTurnAsync(session, ChatTurnStates.Completed, reservedTokens: 640, tokensUsed: 640,
            createdAt: DateTime.UtcNow.AddHours(-1));
        var recent = await database.AddTurnAsync(session, ChatTurnStates.Completed, reservedTokens: 50, tokensUsed: 50);

        await using var db = database.CreateContext();
        var service = Service(db, settings);
        await service.RecoverAsync();
        // The Worker delivering the old event afterwards must not charge again.
        var late = await service.SettleAsync(old.Id, old.Id);

        Assert.Equal(QuotaSettlementStatus.AlreadySettled, late.Status);
        Assert.Equal(9_360, await BalanceAsync(user.Id));
        await using var check = database.CreateContext();
        Assert.Null((await check.ChatMessages.FindAsync(recent.Id))!.QuotaSettledAt);
    }

    [Fact]
    public async Task OverrunStopsAtZeroBalance()
    {
        var user = await database.AddUserAsync(100);
        var session = await database.AddSessionAsync(user.Id);
        var turn = await database.AddTurnAsync(session, ChatTurnStates.Completed, reservedTokens: 500, tokensUsed: 500);

        await using var db = database.CreateContext();
        var result = await Service(db, settings).SettleAsync(turn.Id, turn.Id);

        Assert.Equal(100, result.TokensCharged);
        Assert.Equal(0, await BalanceAsync(user.Id));
    }

    [Fact]
    public async Task ReserveFailsWhenBudgetIsHeldByUnsettledTurns()
    {
        var user = await database.AddUserAsync(1_000);
        var session = await database.AddSessionAsync(user.Id);
        await database.AddTurnAsync(session, ChatTurnStates.Completed, reservedTokens: 1_000, tokensUsed: 1_000);
        var next = await database.AddTurnAsync(session, ChatTurnStates.Processing);

        await using var db = database.CreateContext();
        await Assert.ThrowsAsync<QuotaExceededException>(() =>
            Service(db, settings).ReserveAsync(user.Id, next.Id, 100, TimeSpan.FromMinutes(1)));
    }
}
