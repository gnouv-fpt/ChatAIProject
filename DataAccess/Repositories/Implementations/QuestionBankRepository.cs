using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Models;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public class QuestionBankRepository : GenericRepository<QuestionBank>, IQuestionBankRepository
{
    public QuestionBankRepository(ChatAIWebDbContext context)
        : base(context)
    {
    }

    public async Task<IReadOnlyList<QuestionBank>> GetBanksAsync(
        QuestionBankStatus? status = null,
        CancellationToken cancellationToken = default)
    {
        var query = DbSet.AsNoTracking();
        if (status is not null)
        {
            query = query.Where(b => b.Status == status);
        }

        return await query.OrderBy(b => b.Code).ThenByDescending(b => b.Version).ToListAsync(cancellationToken);
    }

    public Task<QuestionBank?> GetBankAsync(Guid bankId, CancellationToken cancellationToken = default)
    {
        return DbSet.AsNoTracking().FirstOrDefaultAsync(b => b.Id == bankId, cancellationToken);
    }

    public async Task<int?> GetLatestVersionAsync(string code, CancellationToken cancellationToken = default)
    {
        return await DbSet.Where(b => b.Code == code).MaxAsync(b => (int?)b.Version, cancellationToken);
    }

    public async Task<(IReadOnlyList<Question> Items, int TotalCount)> GetQuestionsPagedAsync(
        QuestionQuery query,
        CancellationToken cancellationToken = default)
    {
        var questions = Context.Questions.AsNoTracking().Where(q => q.BankId == query.BankId);

        if (!string.IsNullOrWhiteSpace(query.Topic))
        {
            questions = questions.Where(q => q.Topic == query.Topic);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            questions = questions.Where(q => q.Content.Contains(search));
        }

        if (query.FromNumber is not null)
        {
            questions = questions.Where(q => q.Number >= query.FromNumber);
        }

        if (query.ToNumber is not null)
        {
            questions = questions.Where(q => q.Number <= query.ToNumber);
        }

        if (query.HasImage is not null)
        {
            questions = query.HasImage.Value
                ? questions.Where(q => q.ImagePath != null)
                : questions.Where(q => q.ImagePath == null);
        }

        if (query.IsCritical is not null)
        {
            questions = questions.Where(q => q.IsCritical == query.IsCritical);
        }

        var totalCount = await questions.CountAsync(cancellationToken);
        var items = await questions
            .OrderBy(q => q.Number)
            .Skip((query.PageIndex - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync(cancellationToken);

        return (items, totalCount);
    }

    public async Task<IReadOnlyList<Question>> GetQuestionsByIdsAsync(
        Guid bankId,
        IReadOnlyCollection<Guid> questionIds,
        CancellationToken cancellationToken = default)
    {
        return await Context.Questions.AsNoTracking()
            .Where(q => q.BankId == bankId && questionIds.Contains(q.Id))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<QuestionSummaryRow>> GetQuestionSummariesAsync(
        Guid bankId,
        string? topic = null,
        int? fromNumber = null,
        int? toNumber = null,
        CancellationToken cancellationToken = default)
    {
        var questions = Context.Questions.AsNoTracking().Where(q => q.BankId == bankId);

        if (!string.IsNullOrWhiteSpace(topic))
        {
            questions = questions.Where(q => q.Topic == topic);
        }

        if (fromNumber is not null)
        {
            questions = questions.Where(q => q.Number >= fromNumber);
        }

        if (toNumber is not null)
        {
            questions = questions.Where(q => q.Number <= toNumber);
        }

        return await questions
            .OrderBy(q => q.Number)
            .Select(q => new QuestionSummaryRow(q.Id, q.BankId, q.Number, q.Topic, q.IsCritical, q.ImagePath != null, q.Content))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<TopicCountRow>> GetTopicCountsAsync(Guid bankId, CancellationToken cancellationToken = default)
    {
        return await Context.Questions.AsNoTracking()
            .Where(q => q.BankId == bankId)
            .GroupBy(q => q.Topic)
            .Select(g => new TopicCountRow(g.Key, g.Count()))
            .OrderBy(t => t.Topic)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<ExamTemplate>> GetExamTemplatesAsync(
        Guid bankId,
        bool activeOnly = true,
        CancellationToken cancellationToken = default)
    {
        var templates = Context.ExamTemplates.AsNoTracking().Where(t => t.BankId == bankId);
        if (activeOnly)
        {
            templates = templates.Where(t => t.IsActive);
        }

        return await templates.OrderBy(t => t.Code).ToListAsync(cancellationToken);
    }

    public Task<ExamTemplate?> GetExamTemplateAsync(Guid templateId, CancellationToken cancellationToken = default)
    {
        return Context.ExamTemplates.AsNoTracking().FirstOrDefaultAsync(t => t.Id == templateId, cancellationToken);
    }
}
