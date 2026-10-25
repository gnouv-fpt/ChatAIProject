using BusinessObject.Enums;
using DataAccess.Models;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class LearningProgressRepository : ILearningProgressRepository
{
    private readonly ChatAIWebDbContext _context;

    public LearningProgressRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<AnswerHistoryRow>> GetAnswerHistoryAsync(
        Guid userId,
        Guid bankId,
        CancellationToken cancellationToken = default)
    {
        return await _context.AttemptAnswers.AsNoTracking()
            .Where(a => a.Attempt.UserId == userId && a.Attempt.BankId == bankId)
            .Select(a => new AnswerHistoryRow(
                a.AttemptId,
                a.Attempt.Mode,
                a.Attempt.Status,
                a.QuestionId,
                a.IsCorrect,
                a.AnsweredAt,
                a.Attempt.SubmittedAt))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<AttemptSummaryRow>> GetAttemptSummariesAsync(
        Guid userId,
        Guid bankId,
        CancellationToken cancellationToken = default)
    {
        return await _context.LearningAttempts.AsNoTracking()
            .Where(a => a.UserId == userId && a.BankId == bankId)
            .Select(a => new AttemptSummaryRow(a.Id, a.Mode, a.Status, a.Score, a.IsPassed, a.StartedAt, a.SubmittedAt))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<Guid>> GetBankIdsWithActivityAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.LearningAttempts.AsNoTracking()
            .Where(a => a.UserId == userId)
            .Select(a => a.BankId)
            .Distinct()
            .ToListAsync(cancellationToken);
    }

    public async Task<(IReadOnlyList<AttemptHistoryRow> Items, int TotalCount)> GetAttemptHistoryAsync(
        Guid userId,
        Guid? bankId,
        AttemptMode? mode,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var attempts = _context.LearningAttempts.AsNoTracking().Where(a => a.UserId == userId);

        if (bankId is not null)
        {
            attempts = attempts.Where(a => a.BankId == bankId);
        }

        if (mode is not null)
        {
            attempts = attempts.Where(a => a.Mode == mode);
        }

        var totalCount = await attempts.CountAsync(cancellationToken);
        var items = await attempts
            .OrderByDescending(a => a.StartedAt)
            .Skip((pageIndex - 1) * pageSize)
            .Take(pageSize)
            .Select(a => new AttemptHistoryRow(
                a.Id,
                a.BankId,
                a.Bank.Name,
                a.Bank.Version,
                a.ExamTemplateId,
                a.ExamTemplate != null ? a.ExamTemplate.Name : null,
                a.Mode,
                a.Status,
                a.QuestionCount,
                a.Answers.Count(answer => answer.AnsweredAt != null),
                a.CorrectCount,
                a.Score,
                a.IsPassed,
                a.StartedAt,
                a.DeadlineAt,
                a.SubmittedAt))
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }
}
