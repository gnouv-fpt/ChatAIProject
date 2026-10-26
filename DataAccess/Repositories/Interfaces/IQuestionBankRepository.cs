using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IQuestionBankRepository
{
    Task<IReadOnlyList<QuestionBankPackage>> ListAsync(CancellationToken cancellationToken = default);
    Task<QuestionBankPackage?> GetAsync(Guid id, string version, CancellationToken cancellationToken = default);
    // Returns false for an existing version. Never mutates an imported package.
    Task<bool> AddAsync(QuestionBankPackage package, CancellationToken cancellationToken = default);
    Task<bool> PublishAsync(Guid id, string version, string expectedHash, CancellationToken cancellationToken = default);
}
