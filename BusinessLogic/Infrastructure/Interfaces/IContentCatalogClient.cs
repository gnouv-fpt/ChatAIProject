using BusinessObject.Enums;

namespace BusinessLogic.Infrastructure.Interfaces;

/// <summary>
/// Read-only view of the Content/Exam service (Phúc) that the User module needs for progress/history.
/// The User module must not query Content tables directly; swap the adapter for an HTTP client
/// once the Content API contract is published. Answer keys are never part of this view.
/// </summary>
public interface IContentCatalogClient
{
    Task<IReadOnlyList<CatalogBank>> GetPublishedBanksAsync(CancellationToken cancellationToken = default);

    Task<CatalogBank?> GetBankAsync(Guid bankId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<CatalogBank>> GetBanksByIdsAsync(
        IReadOnlyCollection<Guid> bankIds,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<CatalogQuestion>> GetQuestionsAsync(Guid bankId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<CatalogQuestion>> GetQuestionsByIdsAsync(
        IReadOnlyCollection<Guid> questionIds,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyDictionary<Guid, string>> GetExamTemplateNamesAsync(
        IReadOnlyCollection<Guid> templateIds,
        CancellationToken cancellationToken = default);
}

public sealed record CatalogBank(
    Guid Id,
    string Code,
    string Name,
    int Version,
    string? LicenseClass,
    QuestionBankStatus Status);

public sealed record CatalogQuestion(
    Guid Id,
    Guid BankId,
    int Number,
    string Topic,
    bool IsCritical,
    bool HasImage,
    string Content);
