using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IExamTemplateRepository
{
    Task<IReadOnlyList<ExamTemplate>> ListAsync(bool includeDrafts, CancellationToken ct);
    Task<ExamTemplate?> GetAsync(string code, int version, CancellationToken ct);
    Task<bool> AddAsync(ExamTemplate template, CancellationToken ct);
    Task<bool> PublishAsync(string code, int version, CancellationToken ct);
}
