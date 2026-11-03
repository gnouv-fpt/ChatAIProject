using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

// Server-side content queries. API services must project student DTOs without CorrectAnswerKey.
public interface IQuestionCatalogRepository
{
    Task<IReadOnlyList<TrafficQuestion>> GetByIdsAsync(IReadOnlyList<Guid> ids, CancellationToken cancellationToken);
    Task<IReadOnlyList<TrafficQuestion>> GetPublishedAsync(string bankCode, int bankVersion,
        Guid? categoryId, CancellationToken cancellationToken);
    Task<ExamTemplate?> GetPublishedTemplateAsync(string examCode, int version, CancellationToken cancellationToken);
}
