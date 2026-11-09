using BusinessLogic.Exceptions;

namespace BusinessLogic.Exams;

public sealed class CustomExamService
{
    private readonly IExamQuestionSource _questions;
    private readonly ICustomExamStore _store;
    private readonly IExamResultSink _results;
    private readonly IExamEventPublisher _events;
    private readonly TimeProvider _clock;

    public CustomExamService(IExamQuestionSource questions, ICustomExamStore store,
        IExamResultSink results, IExamEventPublisher events, TimeProvider? clock = null)
    {
        _questions = questions;
        _store = store;
        _results = results;
        _events = events;
        _clock = clock ?? TimeProvider.System;
    }

    public async Task<CustomExamView> CreateAsync(Guid userId, CreateCustomExam request,
        CancellationToken cancellationToken = default)
    {
        if (userId == Guid.Empty || string.IsNullOrWhiteSpace(request.CategoryId) ||
            string.IsNullOrWhiteSpace(request.BankVersion) || request.QuestionCount is < 1 or > 100 ||
            request.DurationMinutes is < 1 or > 180)
            throw new BadRequestException("Thông số tạo đề không hợp lệ.");

        var bankQuestions = await _questions.GetQuestionsAsync(
            request.CategoryId, request.BankVersion, request.QuestionCount, cancellationToken);
        if (request.CategoryCounts is { } quotas)
        {
            if (quotas.Count is < 1 or > 6 || quotas.Any(pair => pair.Key is not ("RULES" or "CULTURE" or "DRIVING" or "MECHANICS" or "SIGN" or "SCENARIO") || pair.Value is < 0 or > 100) ||
                quotas.Values.Sum() != request.QuestionCount)
                throw new BadRequestException("Số câu theo nhóm phải bằng tổng số câu của đề.");
            var selected = new List<BankQuestion>();
            foreach (var (category, amount) in quotas)
            {
                var pool = bankQuestions.Where(q => q.CategoryType == category).ToArray();
                if (pool.Length < amount)
                    throw new BadRequestException($"Nhóm {category} không đủ câu hỏi đã xuất bản.");
                Random.Shared.Shuffle(pool);
                selected.AddRange(pool.Take(amount));
            }
            bankQuestions = selected;
        }
        return await CreateFromQuestionsAsync(userId, request.BankVersion, request.QuestionCount,
            request.DurationMinutes, bankQuestions, true, cancellationToken);
    }

    public async Task<CustomExamView> CreateTemplateAsync(Guid userId, CreateTemplateExam request,
        CancellationToken cancellationToken = default)
    {
        if (userId == Guid.Empty || string.IsNullOrWhiteSpace(request.ExamCode) || request.Version < 1)
            throw new BadRequestException("Mã hoặc phiên bản đề mẫu không hợp lệ.");
        var template = await _questions.GetTemplateAsync(request.ExamCode, request.Version, cancellationToken);
        if (template.Questions is not { Count: > 0 and <= 100 } || template.DurationMinutes is < 1 or > 180 ||
            template.PassingScore is < 1 || template.PassingScore > template.Questions.Count ||
            template.Questions.Any(q => q.PassingScore != template.PassingScore))
            throw new BadRequestException("Đề mẫu trả về dữ liệu không hợp lệ.");
        return await CreateFromQuestionsAsync(userId, template.BankVersion, template.Questions.Count,
            template.DurationMinutes, template.Questions, false, cancellationToken,
            request.ExamCode, request.Version);
    }

    private async Task<CustomExamView> CreateFromQuestionsAsync(Guid userId, string bankVersion,
        int questionCount, int durationMinutes, IReadOnlyList<BankQuestion> bankQuestions,
        bool randomize, CancellationToken cancellationToken, string? templateCode = null, int? templateVersion = null)
    {
        if (bankQuestions.Count < questionCount)
            throw new BadRequestException("Ngân hàng không đủ câu hỏi cho đề đã chọn.");

        if (bankQuestions.Any(q => string.IsNullOrWhiteSpace(q.Id) || string.IsNullOrWhiteSpace(q.Text) ||
                q.Version != bankVersion || string.IsNullOrWhiteSpace(q.CorrectOptionId) ||
                q.Options.Count < 2 || q.Options.Any(o => string.IsNullOrWhiteSpace(o.Id) ||
                    string.IsNullOrWhiteSpace(o.Text)) ||
                q.Options.Select(o => o.Id).Distinct().Count() != q.Options.Count ||
                !q.Options.Any(o => o.Id == q.CorrectOptionId)))
            throw new BadRequestException("Ngân hàng câu hỏi trả về dữ liệu không hợp lệ hoặc trùng câu.");
        var selected = bankQuestions.DistinctBy(q => q.Id).ToArray();
        if (selected.Length < questionCount)
            throw new BadRequestException("Ngân hàng không đủ câu hỏi không trùng cho đề đã chọn.");
        if (randomize) Random.Shared.Shuffle(selected);
        selected = selected.Take(questionCount).ToArray();

        var now = _clock.GetUtcNow();
        var exam = new StoredExam(Guid.NewGuid(), Guid.NewGuid(), userId, bankVersion,
            now, now.AddMinutes(durationMinutes), 0, "Active", null,
            selected.Select(q => new StoredQuestion(q.Id, q.Version, q.Text,
                q.CanShuffleOptions ? Shuffle(q.Options) : q.Options.ToArray(), q.CorrectOptionId, q.IsCritical, q.Assets, q.Explanation, q.ExplanationAnimationUrl)).ToArray(),
            new Dictionary<string, string>(), selected[0].BankId, selected[0].PassingScore,
            selected[0].FailOnCriticalWrong, templateCode, templateVersion);

        // The extra seven days let an in-flight submit retry after the deadline.
        if (!await _store.CreateAsync(exam, TimeSpan.FromMinutes(durationMinutes).Add(TimeSpan.FromDays(7)),
                cancellationToken))
            throw new ConflictException("Không thể tạo đề thi. Vui lòng thử lại.");
        return ToView(exam);
    }

    public async Task<CustomExamView> GetAsync(Guid userId, Guid examId,
        CancellationToken cancellationToken = default)
    {
        var exam = await GetOwnedAsync(userId, examId, cancellationToken);
        return ToView(exam);
    }

    public async Task<CustomExamView> SaveAnswerAsync(Guid userId, Guid examId, string questionId,
        string? optionId, long revision, CancellationToken cancellationToken = default)
    {
        var exam = await GetOwnedAsync(userId, examId, cancellationToken);
        if (exam.Status != "Active" || _clock.GetUtcNow() >= exam.DeadlineUtc)
            throw new ConflictException("Đề thi đã hết giờ hoặc đã nộp.");
        if (revision != exam.Revision)
            throw new ConflictException("Bài làm đã thay đổi. Vui lòng tải lại trước khi lưu.");

        var question = exam.Questions.SingleOrDefault(q => q.Id == questionId)
            ?? throw new BadRequestException("Câu hỏi không thuộc đề thi.");
        if (optionId is not null && !question.Options.Any(o => o.Id == optionId))
            throw new BadRequestException("Phương án không hợp lệ.");

        var answers = new Dictionary<string, string>(exam.Answers);
        if (optionId is null) answers.Remove(questionId);
        else answers[questionId] = optionId;
        var updated = exam with { Answers = answers, Revision = exam.Revision + 1 };
        if (!await _store.CompareExchangeAsync(exam, updated, cancellationToken))
            throw new ConflictException("Bài làm đã thay đổi. Vui lòng tải lại trước khi lưu.");
        return ToView(updated);
    }

    public async Task<ExamScore> SubmitAsync(Guid userId, Guid examId,
        CancellationToken cancellationToken = default)
    {
        var exam = await GetOwnedAsync(userId, examId, cancellationToken);
        // Freeze answers atomically before saving. A retry after a process crash sees
        // the same snapshot and AttemptId; the User service deduplicates that ID.
        if (exam.Status == "Active")
        {
            var frozen = exam with { Status = "Submitting", SubmittedAtUtc = _clock.GetUtcNow(),
                Revision = exam.Revision + 1 };
            if (!await _store.CompareExchangeAsync(exam, frozen, cancellationToken))
                throw new ConflictException("Bài làm đã thay đổi. Vui lòng tải lại trước khi nộp.");
            exam = frozen;
        }
        var submittedAt = exam.SubmittedAtUtc
            ?? throw new ConflictException("Trạng thái đề thi không hợp lệ.");
        var graded = exam.Questions.Select(q => new GradedQuestion(q.Id, q.Version, q.Text,
            q.Options, q.CorrectOptionId, exam.Answers.GetValueOrDefault(q.Id), q.IsCritical, q.Assets, q.Explanation, q.ExplanationAnimationUrl)).ToArray();
        var correct = graded.Count(q => q.SelectedOptionId == q.CorrectOptionId);
        var result = new SaveExamResult(exam.AttemptId, exam.ExamId, userId, exam.BankVersion,
            submittedAt, correct, graded.Length, graded, exam.BankId, exam.CreatedAtUtc, exam.DeadlineUtc,
            exam.PassingScore, exam.FailOnCriticalWrong, exam.TemplateCode, exam.TemplateVersion);
        if (exam.Status == "Submitted")
            return new ExamScore(exam.AttemptId, exam.ExamId, correct, graded.Length, submittedAt);
        if (exam.Status != "Submitting")
            throw new ConflictException("Trạng thái đề thi không hợp lệ.");
        await _results.SaveAsync(result, cancellationToken);
        await _events.PublishAsync(new ExamSubmittedEvent(exam.AttemptId, 1, exam.AttemptId, 1,
            submittedAt, System.Diagnostics.Activity.Current?.Id, userId, examId, correct,
            graded.Length), cancellationToken);
        if (exam.Status == "Submitting")
            await _store.CompareExchangeAsync(exam, exam with { Status = "Submitted", Revision = exam.Revision + 1 },
                cancellationToken);
        return new ExamScore(exam.AttemptId, exam.ExamId, correct, graded.Length, submittedAt);
    }

    private async Task<StoredExam> GetOwnedAsync(Guid userId, Guid examId, CancellationToken cancellationToken)
    {
        var exam = await _store.ReadAsync(examId, cancellationToken)
            ?? throw new NotFoundException("Không tìm thấy đề thi hoặc đề đã hết hạn lưu trữ.");
        if (exam.UserId != userId) throw new ForbiddenException("Bạn không có quyền truy cập đề thi này.");
        return exam;
    }

    private static CustomExamView ToView(StoredExam exam) => new(
        exam.ExamId, exam.BankVersion, exam.DeadlineUtc, exam.Revision, exam.Status,
        exam.Questions.Select(q => new ExamQuestion(q.Id, q.Text, q.Options, q.Assets)).ToArray(),
        exam.Answers, exam.BankId, exam.PassingScore, exam.FailOnCriticalWrong,
        exam.Status == "Submitted" ? exam.AttemptId : null);

    private static IReadOnlyList<ExamOption> Shuffle(IReadOnlyList<ExamOption> options)
    {
        var shuffled = options.ToArray();
        Random.Shared.Shuffle(shuffled);
        return shuffled;
    }
}
