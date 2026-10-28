using BusinessLogic.Exceptions;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Infrastructure.Implementations;

// Transitional fail-closed adapter. Production may not fall back to a writable file bank under C2.
// Replace registration with the Content/Exam SQL adapter when Vuong releases the P0 contract.
public sealed class PendingSqlQuestionBankRepository : IQuestionBankRepository
{
    private static AppException Unavailable() => new(503, "Ngân hàng SQL Content/Exam đang chờ schema/repository P0. File chỉ dùng cho import và kiểm thử.");
    public Task<IReadOnlyList<QuestionBankPackage>> ListAsync(CancellationToken cancellationToken = default) => throw Unavailable();
    public Task<QuestionBankPackage?> GetAsync(Guid id, string version, CancellationToken cancellationToken = default) => throw Unavailable();
    public Task<bool> AddAsync(QuestionBankPackage package, CancellationToken cancellationToken = default) => throw Unavailable();
    public Task<bool> PublishAsync(Guid id, string version, string expectedHash, CancellationToken cancellationToken = default) => throw Unavailable();
}
