using BusinessLogic.Infrastructure.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Infrastructure.Implementations;

/// <summary>
/// Transitional adapter: reads the question-bank tables that still live in the single legacy database.
/// Replace with an HTTP client to the Content/Exam service once the two databases are split (C2 27/10).
/// </summary>
public sealed class LocalContentCatalogClient : IContentCatalogClient
{
    private readonly IQuestionBankRepository _questionBankRepository;
    private readonly IGenericRepository<Question> _questionRepository;
    private readonly IGenericRepository<ExamTemplate> _examTemplateRepository;

    public LocalContentCatalogClient(
        IQuestionBankRepository questionBankRepository,
        IGenericRepository<Question> questionRepository,
        IGenericRepository<ExamTemplate> examTemplateRepository)
    {
        _questionBankRepository = questionBankRepository;
        _questionRepository = questionRepository;
        _examTemplateRepository = examTemplateRepository;
    }

    public async Task<IReadOnlyList<CatalogBank>> GetPublishedBanksAsync(CancellationToken cancellationToken = default)
    {
        var banks = await _questionBankRepository.GetBanksAsync(QuestionBankStatus.Published, cancellationToken);
        return banks.Select(ToBank).ToList();
    }

    public async Task<CatalogBank?> GetBankAsync(Guid bankId, CancellationToken cancellationToken = default)
    {
        var bank = await _questionBankRepository.GetBankAsync(bankId, cancellationToken);
        return bank is null ? null : ToBank(bank);
    }

    public async Task<IReadOnlyList<CatalogBank>> GetBanksByIdsAsync(
        IReadOnlyCollection<Guid> bankIds,
        CancellationToken cancellationToken = default)
    {
        if (bankIds.Count == 0)
        {
            return [];
        }

        var banks = await _questionBankRepository.FindAsync(b => bankIds.Contains(b.Id), cancellationToken);
        return banks.Select(ToBank).ToList();
    }

    public async Task<IReadOnlyList<CatalogQuestion>> GetQuestionsAsync(Guid bankId, CancellationToken cancellationToken = default)
    {
        var rows = await _questionBankRepository.GetQuestionSummariesAsync(bankId, cancellationToken: cancellationToken);
        return rows.Select(q => new CatalogQuestion(q.Id, q.BankId, q.Number, q.Topic, q.IsCritical, q.HasImage, q.Content))
            .ToList();
    }

    public async Task<IReadOnlyList<CatalogQuestion>> GetQuestionsByIdsAsync(
        IReadOnlyCollection<Guid> questionIds,
        CancellationToken cancellationToken = default)
    {
        if (questionIds.Count == 0)
        {
            return [];
        }

        var questions = await _questionRepository.FindAsync(q => questionIds.Contains(q.Id), cancellationToken);
        return questions
            .Select(q => new CatalogQuestion(q.Id, q.BankId, q.Number, q.Topic, q.IsCritical, q.ImagePath != null, q.Content))
            .ToList();
    }

    public async Task<IReadOnlyDictionary<Guid, string>> GetExamTemplateNamesAsync(
        IReadOnlyCollection<Guid> templateIds,
        CancellationToken cancellationToken = default)
    {
        if (templateIds.Count == 0)
        {
            return new Dictionary<Guid, string>();
        }

        var templates = await _examTemplateRepository.FindAsync(t => templateIds.Contains(t.Id), cancellationToken);
        return templates.ToDictionary(t => t.Id, t => t.Name);
    }

    private static CatalogBank ToBank(QuestionBank bank)
    {
        return new CatalogBank(bank.Id, bank.Code, bank.Name, bank.Version, bank.LicenseClass, bank.Status);
    }
}
