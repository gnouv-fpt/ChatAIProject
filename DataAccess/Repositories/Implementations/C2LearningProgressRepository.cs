using System.Text.Json;
using BusinessObject.Enums;
using DataAccess.Models;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class C2LearningProgressRepository(UserDbContext db) : ILearningProgressRepository
{
    // Only the fields needed by queries are read from the durable snapshot; no Content DB joins.
    private sealed record Question(string QuestionId, string CorrectOptionId, string? SelectedOptionId);
    private sealed record Snapshot(Guid BankId, DateTimeOffset? StartedAtUtc, DateTimeOffset? DeadlineUtc, List<Question> Questions);
    private async Task<List<(BusinessObject.Entities.ExamAttempt Attempt, Snapshot Snapshot)>> ReadAsync(Guid user, CancellationToken ct) =>
        (await db.ExamAttempts.AsNoTracking().Where(a => a.UserId == user).OrderByDescending(a => a.SubmittedAt).ToListAsync(ct))
        .Select(a => (a, JsonSerializer.Deserialize<Snapshot>(a.ExamSnapshotJson)!)).ToList();

    public async Task<IReadOnlyList<AnswerHistoryRow>> GetAnswerHistoryAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default) =>
        (await ReadAsync(userId, cancellationToken)).Where(a => a.Snapshot.BankId == bankId).SelectMany(a => a.Snapshot.Questions
            .Select(q => new AnswerHistoryRow(a.Attempt.Id, AttemptMode.Exam, AttemptStatus.Submitted, Guid.Parse(q.QuestionId),
                q.SelectedOptionId == q.CorrectOptionId, a.Attempt.SubmittedAt, a.Attempt.SubmittedAt))).ToList();
    public async Task<IReadOnlyList<AttemptSummaryRow>> GetAttemptSummariesAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default) =>
        (await ReadAsync(userId, cancellationToken)).Where(a => a.Snapshot.BankId == bankId).Select(a => new AttemptSummaryRow(
            a.Attempt.Id, AttemptMode.Exam, AttemptStatus.Submitted, a.Attempt.Score, a.Attempt.IsPassed,
            a.Snapshot.StartedAtUtc?.UtcDateTime ?? a.Attempt.SubmittedAt, a.Attempt.SubmittedAt)).ToList();
    public async Task<IReadOnlyList<Guid>> GetBankIdsWithActivityAsync(Guid userId, CancellationToken cancellationToken = default) =>
        (await ReadAsync(userId, cancellationToken)).Select(a => a.Snapshot.BankId).Distinct().ToList();
    public async Task<(IReadOnlyList<AttemptHistoryRow> Items, int TotalCount)> GetAttemptHistoryAsync(Guid userId, Guid? bankId,
        AttemptMode? mode, int pageIndex, int pageSize, CancellationToken cancellationToken = default)
    {
        var rows = (await ReadAsync(userId, cancellationToken)).Where(a => (bankId is null || a.Snapshot.BankId == bankId) &&
            (mode is null || mode == AttemptMode.Exam)).ToList();
        return (rows.Skip((pageIndex - 1) * pageSize).Take(pageSize).Select(a => new AttemptHistoryRow(a.Attempt.Id,
            a.Snapshot.BankId, null, AttemptMode.Exam, AttemptStatus.Submitted, a.Snapshot.Questions.Count,
            a.Snapshot.Questions.Count(q => q.SelectedOptionId is not null), a.Attempt.Score, a.Attempt.Score, a.Attempt.IsPassed,
            a.Snapshot.StartedAtUtc?.UtcDateTime ?? a.Attempt.SubmittedAt, a.Snapshot.DeadlineUtc?.UtcDateTime,
            a.Attempt.SubmittedAt)).ToList(), rows.Count);
    }
}
