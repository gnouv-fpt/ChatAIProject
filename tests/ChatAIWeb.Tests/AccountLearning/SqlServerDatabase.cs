using BusinessObject.Constants;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace ChatAIWeb.Tests.AccountLearning;

// Quota locks, RowVersion and filtered indexes need real SQL Server, so these tests migrate a throwaway
// database on LocalDB (or the server in BAO_TEST_SQL, without Database=) and drop it afterwards.
public sealed class SqlServerDatabase : IAsyncLifetime
{
    public SqlServerDatabase()
    {
        var server = Environment.GetEnvironmentVariable("BAO_TEST_SQL")
            ?? @"Server=(localdb)\MSSQLLocalDB;Trusted_Connection=True;TrustServerCertificate=true;";
        ConnectionString = $"{server.TrimEnd(';')};Database=ChatAIWebBaoTests_{Guid.NewGuid():N}";
    }

    public string ConnectionString { get; }

    public ChatAIWebDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<ChatAIWebDbContext>()
            .UseSqlServer(ConnectionString, sql => sql.EnableRetryOnFailure())
            .Options;
        return new ChatAIWebDbContext(options);
    }

    public async Task InitializeAsync()
    {
        await using var db = CreateContext();
        await db.Database.MigrateAsync();
    }

    public async Task DisposeAsync()
    {
        await using var db = CreateContext();
        await db.Database.EnsureDeletedAsync();
    }

    public async Task<User> AddUserAsync(int balance = 10_000, UserRole role = UserRole.User)
    {
        await using var db = CreateContext();
        var id = Guid.NewGuid();
        var user = new User
        {
            Id = id,
            Username = "u" + id.ToString("N")[..20],
            Email = id.ToString("N") + "@test.local",
            PasswordHash = "test-only",
            Role = role,
            TokenQuota = balance,
            TokenBalance = balance,
            CreatedAt = DateTime.UtcNow
        };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user;
    }

    public async Task<Guid> AddSessionAsync(Guid userId)
    {
        await using var db = CreateContext();
        var session = new ChatSession
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Title = "Test",
            CreatedAt = DateTime.UtcNow,
            LastUpdatedAt = DateTime.UtcNow
        };
        db.ChatSessions.Add(session);
        await db.SaveChangesAsync();
        return session.Id;
    }

    // An assistant turn as ChatbotService stores it.
    public async Task<ChatMessage> AddTurnAsync(
        Guid sessionId,
        string? turnState,
        int reservedTokens = 0,
        int tokensUsed = 0,
        DateTime? leaseExpiresAt = null,
        DateTime? createdAt = null,
        bool isViolation = false,
        DateTime? quotaSettledAt = null,
        Guid? leaseId = null)
    {
        await using var db = CreateContext();
        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            SessionId = sessionId,
            SenderRole = SenderRole.Assistant,
            Content = turnState == ChatTurnStates.Completed || turnState is null ? "answer" : "",
            CreatedAt = createdAt ?? DateTime.UtcNow,
            RequestId = turnState is null ? null : Guid.NewGuid(),
            RequestHash = turnState is null ? null : "hash",
            TurnState = turnState,
            LeaseId = leaseId,
            LeaseExpiresAt = leaseExpiresAt,
            ReservedTokens = reservedTokens,
            TokensUsed = tokensUsed,
            IsViolation = isViolation,
            QuotaSettledAt = quotaSettledAt
        };
        db.ChatMessages.Add(message);
        await db.SaveChangesAsync();
        return message;
    }

    public async Task AddUserPromptAsync(Guid sessionId)
    {
        await using var db = CreateContext();
        db.ChatMessages.Add(new ChatMessage
        {
            Id = Guid.NewGuid(),
            SessionId = sessionId,
            SenderRole = SenderRole.User,
            Content = "question",
            CreatedAt = DateTime.UtcNow
        });
        await db.SaveChangesAsync();
    }
}
