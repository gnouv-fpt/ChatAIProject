using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class ExamTemplateRepository(ContentDbContext db) : IExamTemplateRepository
{
    public async Task<IReadOnlyList<ExamTemplate>> ListAsync(bool includeDrafts, CancellationToken ct) =>
        await db.ExamTemplates.AsNoTracking().Include(t => t.Items)
            .Where(t => includeDrafts || t.IsPublished)
            .OrderBy(t => t.ExamCode).ThenByDescending(t => t.Version).ToListAsync(ct);

    public Task<ExamTemplate?> GetAsync(string code, int version, CancellationToken ct) =>
        db.ExamTemplates.AsNoTracking().Include(t => t.Items)
            .SingleOrDefaultAsync(t => t.ExamCode == code && t.Version == version, ct);

    public async Task<bool> AddAsync(ExamTemplate template, CancellationToken ct)
    {
        if (await db.ExamTemplates.AnyAsync(t => t.ExamCode == template.ExamCode && t.Version == template.Version, ct)) return false;
        db.ExamTemplates.Add(template);
        try { await db.SaveChangesAsync(ct); return true; }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            if (await GetAsync(template.ExamCode, template.Version, ct) is not null) return false;
            throw;
        }
    }

    public async Task<bool> PublishAsync(string code, int version, CancellationToken ct)
    {
        var template = await db.ExamTemplates.Include(t => t.Items)
            .SingleOrDefaultAsync(t => t.ExamCode == code && t.Version == version, ct);
        if (template is null) return false;
        if (template.IsPublished) return true;
        var ids = template.Items.Select(i => i.QuestionId).ToArray();
        if (await db.TrafficQuestions.CountAsync(q => ids.Contains(q.Id) && q.IsPublished, ct) != ids.Length) return false;
        template.IsPublished = true;
        await db.SaveChangesAsync(ct);
        return true;
    }
}
