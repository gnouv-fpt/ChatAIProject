using BusinessLogic.DTOs;
using BusinessLogic.DTOs.Requests;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Implementations;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess;
using DataAccess.Repositories.Implementations;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace ChatAIWeb.Tests;

// Fake inference is test-only; SQL/SQLite transactions and repositories are real.
public sealed class ChatTests : IAsyncLifetime
{
    private readonly SqliteConnection connection = new("Data Source=:memory:");
    private ChatAIWebDbContext db = null!;
    private readonly Guid userId = Guid.NewGuid();
    private readonly Guid sessionId = Guid.NewGuid();
    private readonly Guid chunkId = Guid.NewGuid();
    private FakeInference inference = new();
    private ChatbotService service = null!;
    private PrivateAttachmentService attachments = null!;
    private readonly ChatSettings settings = new() { AttachmentRoot = Path.Combine(Path.GetTempPath(), "vuong-tests", Guid.NewGuid().ToString("N")), InferenceTimeoutSeconds = 1 };
    private readonly string? sql = Environment.GetEnvironmentVariable("VUONG_TEST_SQL");

    public async Task InitializeAsync()
    {
        var options = new DbContextOptionsBuilder<ChatAIWebDbContext>();
        if (sql == null) { await connection.OpenAsync(); options.UseSqlite(connection); }
        else options.UseSqlServer(sql);
        db = new(options.Options);
        if (sql == null) await db.Database.EnsureCreatedAsync();
        else await db.Database.MigrateAsync();
        db.Users.Add(new User { Id = userId, Username = userId.ToString("N"), Email = userId + "@test.local", PasswordHash = "test-only", TokenBalance = 10000, TokenQuota = 10000, CreatedAt = DateTime.UtcNow });
        db.ChatSessions.Add(new ChatSession { Id = sessionId, UserId = userId, Title = "Test", CreatedAt = DateTime.UtcNow, LastUpdatedAt = DateTime.UtcNow });
        var document = new LegalDocument { Id = Guid.NewGuid(), DocumentNumber = chunkId.ToString(), Title = "Test law", SourceUrl = "https://thuvienphapluat.vn/test", IsActive = true, VerificationStatus = VerificationStatus.Verified, CreatedAt = DateTime.UtcNow };
        db.DocumentChunks.Add(new DocumentChunk { Id = chunkId, Document = document, Content = "Verified test evidence", Article = "1", Clause = "2", IsVerified = true });
        await db.SaveChangesAsync();
        var sessions = new ChatSessionRepository(db);
        attachments = new(settings, sessions);
        service = new(sessions, new ChatMessageRepository(db), new UserRepository(db), inference, new ChatTurnRepository(db), attachments, settings, NullLogger<ChatbotService>.Instance);
    }
    public async Task DisposeAsync() { await db.DisposeAsync(); await connection.DisposeAsync(); if (Directory.Exists(settings.AttachmentRoot)) Directory.Delete(settings.AttachmentRoot, true); }
    private SendMessageRequest Request(string prompt = "Test question") => new() { RequestId = Guid.NewGuid(), Prompt = prompt };

    [Fact] public async Task RetryReturnsSameMessageAndOneEvent()
    {
        var request = Request(); var first = await service.SendMessageAsync(userId, sessionId, request); var replay = await service.SendMessageAsync(userId, sessionId, request);
        Assert.Equal(first.Id, replay.Id); Assert.Equal(1, inference.Calls);
        Assert.Equal(2, await db.ChatMessages.CountAsync(m => m.SessionId == sessionId));
        Assert.Equal(1, await db.ChatMessages.CountAsync(m => m.SessionId == sessionId && m.EventPayload != null));
        Assert.Equal(2, (await service.GetSessionsAsync(userId, 1, 10)).Items.Single().MessageCount);
    }
    [Fact] public async Task ReusingRequestForDifferentPromptConflicts()
    {
        var request = Request(); await service.SendMessageAsync(userId, sessionId, request); request.Prompt = "Other";
        await Assert.ThrowsAsync<ConflictException>(() => service.SendMessageAsync(userId, sessionId, request));
    }
    [Fact] public async Task RpcFailureDoesNotCreateAnswerOrEventAndCanRetry()
    {
        inference.Error = new ServiceUnavailableException("test provider unavailable"); var request = Request();
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.SendMessageAsync(userId, sessionId, request));
        var failed = await db.ChatMessages.SingleAsync(m => m.SessionId == sessionId);
        Assert.Equal("Failed", failed.TurnState); Assert.Null(failed.EventPayload); Assert.Equal(0, failed.ReservedTokens);
        inference.Error = null; await service.SendMessageAsync(userId, sessionId, request); Assert.Equal(2, inference.Calls);
    }
    [Fact] public async Task TimeoutReleasesReservation()
    {
        inference.Delay = TimeSpan.FromSeconds(5);
        await Assert.ThrowsAsync<UpstreamTimeoutException>(() => service.SendMessageAsync(userId, sessionId, Request()));
        Assert.Equal(0, (await db.ChatMessages.SingleAsync(m => m.SessionId == sessionId)).ReservedTokens);
    }
    [Fact] public async Task ZeroBalancePreventsInference()
    {
        (await db.Users.FindAsync(userId))!.TokenBalance = 0; await db.SaveChangesAsync();
        await Assert.ThrowsAsync<QuotaExceededException>(() => service.SendMessageAsync(userId, sessionId, Request())); Assert.Equal(0, inference.Calls);
    }
    [Fact] public async Task CompletedUsageRemainsReservedUntilWorkerSettlement()
    {
        (await db.Users.FindAsync(userId))!.TokenBalance = 10; await db.SaveChangesAsync();
        await service.SendMessageAsync(userId, sessionId, Request());
        await Assert.ThrowsAsync<QuotaExceededException>(() => service.SendMessageAsync(userId, sessionId, Request()));
    }
    [Fact] public async Task WrongOwnerCannotSendOrReadHistory()
    {
        await Assert.ThrowsAsync<NotFoundException>(() => service.SendMessageAsync(Guid.NewGuid(), sessionId, Request()));
        await Assert.ThrowsAsync<NotFoundException>(() => service.GetSessionDetailAsync(Guid.NewGuid(), sessionId)); Assert.Equal(0, inference.Calls);
    }
    [Fact] public async Task PendingRequestConflictsWithoutSecondInference()
    {
        var request = Request();
        db.ChatMessages.Add(new ChatMessage { Id = Guid.NewGuid(), SessionId = sessionId, SenderRole = SenderRole.Assistant, Content = "", RequestId = request.RequestId,
            RequestHash = ChatbotService.Hash(System.Text.Json.JsonSerializer.Serialize(new { prompt = request.Prompt, images = Array.Empty<Guid>(), usePreviousAttachments = true })),
            TurnState = "Processing", LeaseExpiresAt = DateTime.UtcNow.AddMinutes(1), CreatedAt = DateTime.UtcNow, ReservedTokens = 20 }); await db.SaveChangesAsync();
        await Assert.ThrowsAsync<ConflictException>(() => service.SendMessageAsync(userId, sessionId, request)); Assert.Equal(0, inference.Calls);
    }
    [Fact] public async Task PendingTurnsHiddenFromHistory()
    {
        inference.Error = new ServiceUnavailableException("test");
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.SendMessageAsync(userId, sessionId, Request()));
        Assert.Empty((await service.GetSessionDetailAsync(userId, sessionId)).Messages);
    }
    [Fact] public async Task VerifiedCitationMapsSqlIdAndRechecksOnReplay()
    {
        inference.Result = Answer(); var request = Request();
        var result = await service.SendMessageAsync(userId, sessionId, request);
        Assert.Equal(chunkId, result.Citations.Single().DocumentChunkId);
        (await db.DocumentChunks.Include(c => c.Document).SingleAsync(c => c.Id == chunkId)).Document.IsActive = false; await db.SaveChangesAsync();
        await Assert.ThrowsAsync<ConflictException>(() => service.SendMessageAsync(userId, sessionId, request)); Assert.Equal(1, inference.Calls);
    }
    [Fact] public async Task TamperedCitationCannotBeSaved()
    {
        inference.Result = Answer(); inference.Result.Citations[0].ContentHash = "wrong";
        await Assert.ThrowsAsync<ConflictException>(() => service.SendMessageAsync(userId, sessionId, Request()));
        Assert.False(await db.Citations.AnyAsync(c => c.DocumentChunkId == chunkId));
    }
    [Theory] [InlineData("Answered", false)] [InlineData("Invalid", true)]
    public async Task InvalidAiResponseIsNotSuccessful(string status, bool verified)
    {
        inference.Result = new() { ContractVersion = 2, Status = status, DataVerified = verified, ResponseText = "Invalid" };
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.SendMessageAsync(userId, sessionId, Request()));
    }
    [Fact] public async Task OlderAiContractFailsClosed()
    {
        inference.Result.ContractVersion = 0;
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.SendMessageAsync(userId, sessionId, Request()));
    }
    [Fact] public async Task AttachmentOwnershipAndSessionAreEnforced()
    {
        var uploaded = await attachments.UploadAsync(userId, sessionId, "image/png", new MemoryStream(Png), default);
        var image = await attachments.ReadAsync(userId, sessionId, uploaded.Id, default); Assert.Equal(Png, image.Content);
        await Assert.ThrowsAsync<NotFoundException>(() => attachments.ReadAsync(Guid.NewGuid(), sessionId, uploaded.Id, default));
        await Assert.ThrowsAsync<NotFoundException>(() => attachments.ReadAsync(userId, Guid.NewGuid(), uploaded.Id, default));
    }
    [Fact] public async Task ImageAndFollowUpReachInference()
    {
        var uploaded = await attachments.UploadAsync(userId, sessionId, "image/png", new MemoryStream(Png), default);
        inference.Result.ImagesProcessed = true;
        var first = Request(); first.AttachmentIds = [uploaded.Id]; await service.SendMessageAsync(userId, sessionId, first);
        await service.SendMessageAsync(userId, sessionId, Request("Follow up"));
        Assert.Single(inference.LastInput!.Images); Assert.Equal(2, inference.LastInput.History.Count);
    }
    [Fact] public async Task UnsupportedVisionDoesNotSilentlySendTextOnly()
    {
        var uploaded = await attachments.UploadAsync(userId, sessionId, "image/png", new MemoryStream(Png), default);
        var request = Request(); request.AttachmentIds = [uploaded.Id];
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.SendMessageAsync(userId, sessionId, request));
    }
    [Theory] [InlineData("text/html")] [InlineData("image/png")] [InlineData("image/jpeg")]
    public async Task NonImageOrSpoofedMimeRejected(string mime) =>
        await Assert.ThrowsAsync<BadRequestException>(() => attachments.UploadAsync(userId, sessionId, mime, new MemoryStream("not an image"u8.ToArray()), default));
    [Fact] public async Task ImageTamperingDetected()
    {
        var image = await attachments.UploadAsync(userId, sessionId, "image/png", new MemoryStream(Png), default);
        await File.WriteAllBytesAsync(Path.Combine(settings.AttachmentRoot, userId.ToString("N"), image.Id.ToString("N") + ".bin"), [1, 2, 3]);
        await Assert.ThrowsAsync<ConflictException>(() => attachments.ReadAsync(userId, sessionId, image.Id, default));
    }
    [Fact] public async Task OversizedStreamRejectedWithoutTrustingLength()
    {
        settings.MaxAttachmentBytes = 1024;
        await Assert.ThrowsAsync<BadRequestException>(() => attachments.UploadAsync(userId, sessionId, "image/png", new MemoryStream(new byte[1025]), default));
    }
    [Fact] public async Task RetentionRemovesExpiredFiles()
    {
        var image = await attachments.UploadAsync(userId, sessionId, "image/png", new MemoryStream(Png), default);
        foreach (var file in Directory.GetFiles(settings.AttachmentRoot, "*.*", SearchOption.AllDirectories)) File.SetLastWriteTimeUtc(file, DateTime.UtcNow.AddDays(-2));
        await attachments.CleanupAsync(default);
        await Assert.ThrowsAsync<NotFoundException>(() => attachments.ReadAsync(userId, sessionId, image.Id, default));
    }
    [Fact] public async Task ExpiredLeaseCanBeRecoveredWithoutDuplicatingMessages()
    {
        inference.Error = new ServiceUnavailableException("test"); var request = Request();
        await Assert.ThrowsAsync<ServiceUnavailableException>(() => service.SendMessageAsync(userId, sessionId, request));
        var stale = await db.ChatMessages.SingleAsync(m => m.SessionId == sessionId);
        stale.TurnState = "Processing"; stale.LeaseExpiresAt = DateTime.UtcNow.AddMinutes(-2); stale.ReservedTokens = 4096;
        await db.SaveChangesAsync(); inference.Error = null;
        await service.SendMessageAsync(userId, sessionId, request);
        Assert.Equal(2, await db.ChatMessages.CountAsync(m => m.SessionId == sessionId));
    }
    [SqlFact] public async Task ConcurrentDuplicateAcrossDbContextsMakesOneInference()
    {
        var gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        inference.Gate = gate.Task; settings.InferenceTimeoutSeconds = 10;
        var request = Request(); var first = service.SendMessageAsync(userId, sessionId, request);
        while (inference.LastInput == null) await Task.Delay(10);
        await using var otherDb = new ChatAIWebDbContext(new DbContextOptionsBuilder<ChatAIWebDbContext>().UseSqlServer(sql, o => o.EnableRetryOnFailure()).Options);
        var second = NewService(otherDb);
        await Assert.ThrowsAsync<ConflictException>(() => second.SendMessageAsync(userId, sessionId, request));
        gate.SetResult(); await first; Assert.Equal(1, inference.Calls);
    }
    [SqlFact] public async Task ConcurrentDifferentRequestsCannotReserveSameBalance()
    {
        (await db.Users.FindAsync(userId))!.TokenBalance = 20; await db.SaveChangesAsync();
        var gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        inference.Gate = gate.Task; settings.InferenceTimeoutSeconds = 10;
        var first = service.SendMessageAsync(userId, sessionId, Request());
        while (inference.LastInput == null) await Task.Delay(10);
        await using var otherDb = new ChatAIWebDbContext(new DbContextOptionsBuilder<ChatAIWebDbContext>().UseSqlServer(sql, o => o.EnableRetryOnFailure()).Options);
        await Assert.ThrowsAsync<QuotaExceededException>(() => NewService(otherDb).SendMessageAsync(userId, sessionId, Request()));
        gate.SetResult(); await first; Assert.Equal(1, inference.Calls);
    }
    [Fact] public async Task UserCanDisableImageInheritance()
    {
        var uploaded = await attachments.UploadAsync(userId, sessionId, "image/png", new MemoryStream(Png), default);
        inference.Result.ImagesProcessed = true; var first = Request(); first.AttachmentIds = [uploaded.Id];
        await service.SendMessageAsync(userId, sessionId, first);
        var next = Request(); next.UsePreviousAttachments = false; await service.SendMessageAsync(userId, sessionId, next);
        Assert.Empty(inference.LastInput!.Images);
    }
    private ChatbotService NewService(ChatAIWebDbContext otherDb) => new(new ChatSessionRepository(otherDb), new ChatMessageRepository(otherDb),
        new UserRepository(otherDb), inference, new ChatTurnRepository(otherDb), new PrivateAttachmentService(settings, new ChatSessionRepository(otherDb)),
        settings, NullLogger<ChatbotService>.Instance);
    private ChatInferenceResultDto Answer() => new()
    {
        ContractVersion = 2, Status = "Answered", DataVerified = true, ResponseText = "Verified answer", TokensUsed = 10,
        Citations = [new() { ChunkId = chunkId.ToString(), ContentHash = ChatbotService.Hash("Verified test evidence"), DocumentTitle = "Test law", ArticleNumber = "1", ClauseNumber = "2", SourceUrl = "https://thuvienphapluat.vn/test", Excerpt = "Verified test evidence" }]
    };
    private static readonly byte[] Png = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4XcAAAAASUVORK5CYII=");
    private sealed class FakeInference : IGrpcInferenceService
    {
        public int Calls; public Exception? Error; public TimeSpan Delay; public Task? Gate;
        public ChatInferenceInputDto? LastInput;
        public ChatInferenceResultDto Result = new() { ContractVersion = 2, Status = "NoMatch", ResponseText = "No match in test fixture", TokensUsed = 10 };
        public async Task<ChatInferenceResultDto> ProcessTurnAsync(ChatInferenceInputDto input, CancellationToken cancellationToken = default)
        { Interlocked.Increment(ref Calls); LastInput = input; if (Error != null) throw Error; if (Gate != null) await Gate.WaitAsync(cancellationToken); await Task.Delay(Delay, cancellationToken); return Result; }
        public Task<ChatInferenceResultDto> ProcessChatMessageAsync(string userId, string sessionId, string prompt, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<VerificationResultDto> VerifyLegalDocumentAsync(string documentTitle, string documentNumber, string content, CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<IndexDocumentResultDto> IndexDocumentAsync(IEnumerable<DocumentChunkInputDto> chunks, CancellationToken cancellationToken = default) => throw new NotSupportedException();
    }
}

public sealed class SqlFactAttribute : FactAttribute
{
    public SqlFactAttribute() { if (Environment.GetEnvironmentVariable("VUONG_TEST_SQL") == null) Skip = "Requires dedicated SQL Server test database"; }
}
