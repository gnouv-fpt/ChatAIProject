using BusinessLogic.DTOs.Responses;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Models;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace BusinessLogic.Services.Implementations;

public sealed class LearningProgressService : ILearningProgressService
{
    private const int MaxPageSize = 100;
    private const int PreviewLength = 160;
    private const string UnknownBankName = "Bộ câu hỏi không còn tồn tại";

    private readonly ILearningProgressRepository _progressRepository;
    private readonly IContentCatalogClient _contentCatalog;
    private readonly IQuestionBookmarkRepository _bookmarkRepository;

    // Bank/question data comes from the Content service through IContentCatalogClient; this
    // service only queries User-owned data (attempts, answers, bookmarks).
    public LearningProgressService(
        ILearningProgressRepository progressRepository,
        IContentCatalogClient contentCatalog,
        IQuestionBookmarkRepository bookmarkRepository)
    {
        _progressRepository = progressRepository;
        _contentCatalog = contentCatalog;
        _bookmarkRepository = bookmarkRepository;
    }

    public async Task<IReadOnlyList<BankProgressDto>> GetOverviewAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var banks = (await _contentCatalog.GetPublishedBanksAsync(cancellationToken)).ToList();
        var otherBankIds = (await _progressRepository.GetBankIdsWithActivityAsync(userId, cancellationToken))
            .Where(id => banks.All(b => b.Id != id))
            .ToList();
        banks.AddRange(await _contentCatalog.GetBanksByIdsAsync(otherBankIds, cancellationToken));

        var result = new List<BankProgressDto>();
        foreach (var bank in banks)
        {
            result.Add(await BuildProgressAsync(userId, bank, includeTopics: false, cancellationToken));
        }

        return result;
    }

    public async Task<BankProgressDto> GetBankProgressAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default)
    {
        var bank = await RequireVisibleBankAsync(bankId, cancellationToken);
        return await BuildProgressAsync(userId, bank, includeTopics: true, cancellationToken);
    }

    public async Task<PagedResultDto<QuestionProgressItemDto>> GetWrongQuestionsAsync(
        Guid userId,
        Guid bankId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        await RequireVisibleBankAsync(bankId, cancellationToken);
        var questions = await _contentCatalog.GetQuestionsAsync(bankId, cancellationToken);
        var states = await GetQuestionStatesAsync(userId, bankId, cancellationToken);

        var items = questions
            .Where(q => states.TryGetValue(q.Id, out var state) && !state.LatestCorrect)
            .Select(q => ToItem(q, states[q.Id]))
            .ToList();
        return Page(items, pageIndex, pageSize);
    }

    public async Task<PagedResultDto<QuestionProgressItemDto>> GetUnseenQuestionsAsync(
        Guid userId,
        Guid bankId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        await RequireVisibleBankAsync(bankId, cancellationToken);
        var questions = await _contentCatalog.GetQuestionsAsync(bankId, cancellationToken);
        var states = await GetQuestionStatesAsync(userId, bankId, cancellationToken);

        var items = questions
            .Where(q => !states.ContainsKey(q.Id))
            .Select(q => ToItem(q, null))
            .ToList();
        return Page(items, pageIndex, pageSize);
    }

    public async Task<IReadOnlyList<Guid>> GetWrongQuestionIdsAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default)
    {
        var states = await GetQuestionStatesAsync(userId, bankId, cancellationToken);
        return states.Values.Where(s => !s.LatestCorrect).Select(s => s.QuestionId).ToList();
    }

    public async Task<IReadOnlyList<Guid>> GetUnseenQuestionIdsAsync(Guid userId, Guid bankId, CancellationToken cancellationToken = default)
    {
        var questions = await _contentCatalog.GetQuestionsAsync(bankId, cancellationToken);
        var states = await GetQuestionStatesAsync(userId, bankId, cancellationToken);
        return questions.Where(q => !states.ContainsKey(q.Id)).Select(q => q.Id).ToList();
    }

    public async Task<PagedResultDto<AttemptHistoryItemDto>> GetHistoryAsync(
        Guid userId,
        Guid? bankId,
        AttemptMode? mode,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        (pageIndex, pageSize) = NormalizePage(pageIndex, pageSize);
        var (rows, totalCount) = await _progressRepository.GetAttemptHistoryAsync(
            userId, bankId, mode, pageIndex, pageSize, cancellationToken);

        var banks = (await _contentCatalog.GetBanksByIdsAsync(rows.Select(r => r.BankId).Distinct().ToList(), cancellationToken))
            .ToDictionary(b => b.Id);
        var templateNames = await _contentCatalog.GetExamTemplateNamesAsync(
            rows.Where(r => r.ExamTemplateId is not null).Select(r => r.ExamTemplateId!.Value).Distinct().ToList(),
            cancellationToken);

        return new PagedResultDto<AttemptHistoryItemDto>
        {
            Items = rows.Select(r =>
                {
                    banks.TryGetValue(r.BankId, out var bank);
                    var templateName = r.ExamTemplateId is { } templateId ? templateNames.GetValueOrDefault(templateId) : null;
                    return new AttemptHistoryItemDto(
                        r.Id, r.BankId, bank?.Name ?? UnknownBankName, bank?.Version ?? 0, r.ExamTemplateId, templateName,
                        r.Mode, r.Status, r.QuestionCount, r.AnsweredCount, r.CorrectCount, r.Score, r.IsPassed,
                        r.StartedAt, r.DeadlineAt, r.SubmittedAt);
                })
                .ToList(),
            TotalCount = totalCount,
            PageIndex = pageIndex,
            PageSize = pageSize
        };
    }

    public async Task<PagedResultDto<BookmarkItemDto>> GetBookmarksAsync(
        Guid userId,
        Guid? bankId,
        int pageIndex,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        (pageIndex, pageSize) = NormalizePage(pageIndex, pageSize);
        IReadOnlyCollection<Guid>? bankQuestionIds = null;
        if (bankId is { } id)
        {
            bankQuestionIds = (await _contentCatalog.GetQuestionsAsync(id, cancellationToken)).Select(q => q.Id).ToList();
        }

        var (rows, totalCount) = await _bookmarkRepository.GetPagedAsync(
            userId, bankQuestionIds, pageIndex, pageSize, cancellationToken);

        var questions = (await _contentCatalog.GetQuestionsByIdsAsync(rows.Select(r => r.QuestionId).ToList(), cancellationToken))
            .ToDictionary(q => q.Id);
        var banks = (await _contentCatalog.GetBanksByIdsAsync(
                questions.Values.Select(q => q.BankId).Distinct().ToList(), cancellationToken))
            .ToDictionary(b => b.Id);

        return new PagedResultDto<BookmarkItemDto>
        {
            // A bookmark whose question no longer exists in the Content service is not shown.
            Items = rows.Where(r => questions.ContainsKey(r.QuestionId)).Select(r =>
                {
                    var question = questions[r.QuestionId];
                    banks.TryGetValue(question.BankId, out var bank);
                    return new BookmarkItemDto(
                        question.Id, question.BankId, bank?.Name ?? UnknownBankName, bank?.Version ?? 0, question.Number,
                        question.Topic, Preview(question.Content), question.HasImage, r.BookmarkedAt);
                })
                .ToList(),
            TotalCount = totalCount,
            PageIndex = pageIndex,
            PageSize = pageSize
        };
    }

    public async Task AddBookmarkAsync(Guid userId, Guid questionId, CancellationToken cancellationToken = default)
    {
        var question = (await _contentCatalog.GetQuestionsByIdsAsync([questionId], cancellationToken)).FirstOrDefault()
            ?? throw new NotFoundException("Không tìm thấy câu hỏi.");
        await RequireVisibleBankAsync(question.BankId, cancellationToken);

        if (await _bookmarkRepository.GetAsync(userId, questionId, cancellationToken) is not null)
        {
            return;
        }

        await _bookmarkRepository.AddAsync(new QuestionBookmark
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            QuestionId = questionId,
            CreatedAt = DateTime.UtcNow
        }, cancellationToken);

        try
        {
            await _bookmarkRepository.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            // A concurrent request may have created the same bookmark; the unique index kept a single row.
            if (!await _bookmarkRepository.AnyAsync(b => b.UserId == userId && b.QuestionId == questionId, cancellationToken))
            {
                throw;
            }
        }
    }

    public async Task RemoveBookmarkAsync(Guid userId, Guid questionId, CancellationToken cancellationToken = default)
    {
        var bookmark = await _bookmarkRepository.GetAsync(userId, questionId, cancellationToken);
        if (bookmark is null)
        {
            return;
        }

        _bookmarkRepository.Remove(bookmark);
        await _bookmarkRepository.SaveChangesAsync(cancellationToken);
    }

    private async Task<BankProgressDto> BuildProgressAsync(
        Guid userId,
        CatalogBank bank,
        bool includeTopics,
        CancellationToken cancellationToken)
    {
        var questions = await _contentCatalog.GetQuestionsAsync(bank.Id, cancellationToken);
        var history = await _progressRepository.GetAnswerHistoryAsync(userId, bank.Id, cancellationToken);
        var attempts = await _progressRepository.GetAttemptSummariesAsync(userId, bank.Id, cancellationToken);
        var bookmarkedIds = (await _bookmarkRepository.GetQuestionIdsAsync(userId, cancellationToken)).ToHashSet();
        var bookmarkCount = questions.Count(q => bookmarkedIds.Contains(q.Id));

        var graded = history.Where(IsGraded).ToList();
        var states = BuildStates(graded);
        var correctAnswers = graded.Count(r => r.IsCorrect == true);
        var completedExams = attempts.Where(a => a.Mode == AttemptMode.Exam && IsFinished(a.Status)).ToList();

        var lastActivity = attempts
            .Select(a => (DateTime?)(a.SubmittedAt ?? a.StartedAt))
            .Concat(history.Select(r => r.AnsweredAt))
            .Max();

        var topics = includeTopics
            ? questions
                .GroupBy(q => q.Topic)
                .OrderBy(g => g.Key)
                .Select(g => new TopicProgressDto(
                    g.Key,
                    g.Count(),
                    g.Count(q => states.ContainsKey(q.Id)),
                    g.Count(q => states.TryGetValue(q.Id, out var s) && s.LatestCorrect),
                    g.Count(q => states.TryGetValue(q.Id, out var s) && !s.LatestCorrect)))
                .ToList()
            : new List<TopicProgressDto>();

        return new BankProgressDto(
            bank.Id,
            bank.Code,
            bank.Name,
            bank.Version,
            bank.LicenseClass,
            bank.Status,
            questions.Count,
            states.Count,
            states.Values.Count(s => s.LatestCorrect),
            states.Values.Count(s => !s.LatestCorrect),
            questions.Count - states.Count,
            bookmarkCount,
            graded.Count,
            correctAnswers,
            graded.Count == 0 ? 0 : Math.Round(correctAnswers * 100.0 / graded.Count, 1),
            attempts.Count(a => a.Mode == AttemptMode.Practice),
            completedExams.Count,
            completedExams.Count(a => a.IsPassed == true),
            completedExams.Max(a => a.Score),
            lastActivity,
            topics);
    }

    private async Task<Dictionary<Guid, QuestionState>> GetQuestionStatesAsync(
        Guid userId,
        Guid bankId,
        CancellationToken cancellationToken)
    {
        var history = await _progressRepository.GetAnswerHistoryAsync(userId, bankId, cancellationToken);
        return BuildStates(history.Where(IsGraded));
    }

    // An answer counts once it is graded: practice answers immediately, exam answers only after the exam ended.
    // Each (attempt, question) is a single row, so retried submits can never add answers twice.
    private static bool IsGraded(AnswerHistoryRow row)
    {
        return row.IsCorrect is not null
            && (row.Mode == AttemptMode.Practice || IsFinished(row.AttemptStatus));
    }

    private static bool IsFinished(AttemptStatus status) => status is AttemptStatus.Submitted or AttemptStatus.Expired;

    private static Dictionary<Guid, QuestionState> BuildStates(IEnumerable<AnswerHistoryRow> graded)
    {
        return graded
            .GroupBy(r => r.QuestionId)
            .ToDictionary(g => g.Key, g =>
            {
                var latest = g.OrderByDescending(r => r.AnsweredAt ?? r.SubmittedAt).First();
                return new QuestionState(
                    g.Key,
                    latest.IsCorrect == true,
                    g.Count(r => r.IsCorrect == false),
                    latest.AnsweredAt ?? latest.SubmittedAt);
            });
    }

    private async Task<CatalogBank> RequireVisibleBankAsync(Guid bankId, CancellationToken cancellationToken)
    {
        var bank = await _contentCatalog.GetBankAsync(bankId, cancellationToken);
        // Draft banks are not visible to learners; retired ones stay readable for history.
        if (bank is null || bank.Status == QuestionBankStatus.Draft)
        {
            throw new NotFoundException("Không tìm thấy bộ câu hỏi.");
        }

        return bank;
    }

    private static QuestionProgressItemDto ToItem(CatalogQuestion question, QuestionState? state)
    {
        return new QuestionProgressItemDto(
            question.Id,
            question.Number,
            question.Topic,
            question.IsCritical,
            question.HasImage,
            Preview(question.Content),
            state?.WrongAnswers ?? 0,
            state?.LastAnsweredAt);
    }

    private static string Preview(string content)
    {
        return content.Length <= PreviewLength ? content : content[..PreviewLength] + "…";
    }

    private static (int PageIndex, int PageSize) NormalizePage(int pageIndex, int pageSize)
    {
        return (Math.Max(1, pageIndex), Math.Clamp(pageSize, 1, MaxPageSize));
    }

    private static PagedResultDto<T> Page<T>(IReadOnlyList<T> items, int pageIndex, int pageSize)
    {
        (pageIndex, pageSize) = NormalizePage(pageIndex, pageSize);
        return new PagedResultDto<T>
        {
            Items = items.Skip((pageIndex - 1) * pageSize).Take(pageSize).ToList(),
            TotalCount = items.Count,
            PageIndex = pageIndex,
            PageSize = pageSize
        };
    }

    private sealed record QuestionState(Guid QuestionId, bool LatestCorrect, int WrongAnswers, DateTime? LastAnsweredAt);
}
