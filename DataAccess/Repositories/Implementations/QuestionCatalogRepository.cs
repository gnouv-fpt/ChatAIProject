using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class QuestionCatalogRepository(ContentDbContext db) : IQuestionCatalogRepository
{
    public async Task<IReadOnlyList<TrafficQuestion>> GetByIdsAsync(IReadOnlyList<Guid> ids, CancellationToken ct) =>
        await db.TrafficQuestions.AsNoTracking().Where(q => ids.Contains(q.Id)).ToListAsync(ct);

    public async Task<IReadOnlyList<TrafficQuestion>> GetPublishedAsync(string bankCode, int bankVersion,
        Guid? categoryId, CancellationToken ct) =>
        await db.TrafficQuestions.AsNoTracking().Where(q => q.BankCode == bankCode && q.BankVersion == bankVersion &&
            q.IsPublished && (!categoryId.HasValue || q.CategoryId == categoryId))
            .OrderBy(q => q.QuestionCode).ToListAsync(ct);

    public Task<ExamTemplate?> GetPublishedTemplateAsync(string examCode, int version, CancellationToken ct) =>
        db.ExamTemplates.AsNoTracking().Include(t => t.Items.OrderBy(i => i.OrderIndex)).ThenInclude(i => i.Question)
            .SingleOrDefaultAsync(t => t.ExamCode == examCode && t.Version == version && t.IsPublished &&
                t.Items.All(i => i.Question.IsPublished), ct);
}
