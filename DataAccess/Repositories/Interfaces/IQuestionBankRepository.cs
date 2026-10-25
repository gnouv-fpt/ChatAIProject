using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Models;

namespace DataAccess.Repositories.Interfaces;

// Shared by question-bank import/publish (Phúc) and practice/exam selection (Khánh).
// Add a new bank version with its Questions/ExamTemplates through AddAsync + SaveChangesAsync.
public interface IQuestionBankRepository : IGenericRepository<QuestionBank>
{
    Task<IReadOnlyList<QuestionBank>> GetBanksAsync(
        QuestionBankStatus? status = null,
        CancellationToken cancellationToken = default);

    Task<QuestionBank?> GetBankAsync(Guid bankId, CancellationToken cancellationToken = default);

    Task<int?> GetLatestVersionAsync(string code, CancellationToken cancellationToken = default);

    Task<(IReadOnlyList<Question> Items, int TotalCount)> GetQuestionsPagedAsync(
        QuestionQuery query,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Question>> GetQuestionsByIdsAsync(
        Guid bankId,
        IReadOnlyCollection<Guid> questionIds,
        CancellationToken cancellationToken = default);

    // Candidate pool for selection; filters are optional and combined with AND.
    Task<IReadOnlyList<QuestionSummaryRow>> GetQuestionSummariesAsync(
        Guid bankId,
        string? topic = null,
        int? fromNumber = null,
        int? toNumber = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TopicCountRow>> GetTopicCountsAsync(Guid bankId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ExamTemplate>> GetExamTemplatesAsync(
        Guid bankId,
        bool activeOnly = true,
        CancellationToken cancellationToken = default);

    Task<ExamTemplate?> GetExamTemplateAsync(Guid templateId, CancellationToken cancellationToken = default);
}
