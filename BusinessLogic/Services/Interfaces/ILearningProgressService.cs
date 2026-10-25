using BusinessLogic.DTOs.Responses;
using BusinessObject.Enums;

namespace BusinessLogic.Services.Interfaces;

// Progress is derived from graded AttemptAnswers of one bank version; nothing is stored separately.
public interface ILearningProgressService
{
    // Summary per published bank and per bank the user has attempts in (topics left empty).
    Task<IReadOnlyList<BankProgressDto>> GetOverviewAsync(Guid userId, CancellationToken cancellationToken = default);

    Task<BankProgressDto> GetBankProgressAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default);

    Task<PagedResultDto<QuestionProgressItemDto>> GetWrongQuestionsAsync(
        Guid userId,
        Guid bankId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<PagedResultDto<QuestionProgressItemDto>> GetUnseenQuestionsAsync(
        Guid userId,
        Guid bankId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default);

    // For practice selection: IDs whose latest graded answer is wrong / that have no graded answer yet.
    Task<IReadOnlyList<Guid>> GetWrongQuestionIdsAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Guid>> GetUnseenQuestionIdsAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default);

    Task<PagedResultDto<AttemptHistoryItemDto>> GetHistoryAsync(
        Guid userId,
        Guid? bankId,
        AttemptMode? mode,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<PagedResultDto<BookmarkItemDto>> GetBookmarksAsync(
        Guid userId,
        Guid? bankId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default);

    // Idempotent: bookmarking twice or removing a missing bookmark is not an error.
    Task AddBookmarkAsync(Guid userId, Guid questionId, CancellationToken cancellationToken = default);

    Task RemoveBookmarkAsync(Guid userId, Guid questionId, CancellationToken cancellationToken = default);
}
