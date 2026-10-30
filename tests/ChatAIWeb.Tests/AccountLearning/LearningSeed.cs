using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess;

namespace ChatAIWeb.Tests.AccountLearning;

// Test fixture data only: a 4-question bank and attempts in the shapes the practice/exam engine stores.
public sealed class LearningSeed
{
    public Guid BankId { get; } = Guid.NewGuid();
    public Guid DraftBankId { get; } = Guid.NewGuid();
    public Guid[] Questions { get; } = Enumerable.Range(0, 4).Select(_ => Guid.NewGuid()).ToArray();

    public async Task AddBanksAsync(ChatAIWebDbContext db)
    {
        var code = "TEST-" + BankId.ToString("N")[..8];
        db.QuestionBanks.Add(Bank(BankId, code, 1, QuestionBankStatus.Published, Questions));
        db.QuestionBanks.Add(Bank(DraftBankId, code, 2, QuestionBankStatus.Draft, [Guid.NewGuid()]));
        await db.SaveChangesAsync();
    }

    // P1: Q1 right, Q2 wrong, Q3 open. P2: Q2 right. E1 (running): Q4 answered, not graded. E2 (submitted): Q1 right, Q3 wrong.
    public async Task AddAttemptsAsync(ChatAIWebDbContext db, Guid userId)
    {
        var t = DateTime.UtcNow.AddHours(-3);
        db.LearningAttempts.AddRange(
            Attempt(userId, AttemptMode.Practice, AttemptStatus.InProgress, t, null,
                Answer(0, true, t.AddMinutes(1)), Answer(1, false, t.AddMinutes(2)), Answer(2, null, null)),
            Attempt(userId, AttemptMode.Practice, AttemptStatus.Submitted, t.AddMinutes(10), t.AddMinutes(12),
                Answer(1, true, t.AddMinutes(11))),
            Attempt(userId, AttemptMode.Exam, AttemptStatus.InProgress, t.AddMinutes(20), null,
                Answer(3, null, t.AddMinutes(21))),
            Attempt(userId, AttemptMode.Exam, AttemptStatus.Submitted, t.AddMinutes(30), t.AddMinutes(40),
                Answer(0, true, t.AddMinutes(31)), Answer(2, false, t.AddMinutes(32))));
        await db.SaveChangesAsync();
    }

    private QuestionBank Bank(Guid id, string code, int version, QuestionBankStatus status, Guid[] questionIds)
    {
        return new QuestionBank
        {
            Id = id,
            Code = code,
            Version = version,
            Name = "Bộ đề thử nghiệm",
            ManifestHash = new string('a', 64),
            Status = status,
            QuestionCount = questionIds.Length,
            CreatedAt = DateTime.UtcNow,
            PublishedAt = status == QuestionBankStatus.Published ? DateTime.UtcNow : null,
            Questions = questionIds.Select((qid, i) => new Question
            {
                Id = qid,
                Number = i + 1,
                ExternalId = $"Q{i + 1}",
                Content = $"Câu hỏi thử nghiệm {i + 1}",
                Topic = i < 2 ? "Biển báo" : "Sa hình",
                IsCritical = i == 0,
                AllowOptionShuffle = true,
                Options = [new QuestionOption { OptionId = "A", Text = "Đúng" }, new QuestionOption { OptionId = "B", Text = "Sai" }],
                CorrectOptionIds = ["A"],
                ContentHash = new string('b', 64)
            }).ToList()
        };
    }

    private LearningAttempt Attempt(Guid userId, AttemptMode mode, AttemptStatus status, DateTime startedAt,
        DateTime? submittedAt, params (int Index, bool? IsCorrect, DateTime? AnsweredAt)[] answers)
    {
        var attempt = new LearningAttempt
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            BankId = BankId,
            Mode = mode,
            Status = status,
            QuestionCount = answers.Length,
            StartedAt = startedAt,
            DeadlineAt = mode == AttemptMode.Exam ? startedAt.AddMinutes(19) : null,
            SubmittedAt = submittedAt,
            Score = mode == AttemptMode.Exam && submittedAt is not null ? answers.Count(a => a.IsCorrect == true) : null,
            IsPassed = mode == AttemptMode.Exam && submittedAt is not null ? false : null
        };
        attempt.Answers = answers.Select((a, position) => new AttemptAnswer
        {
            Id = Guid.NewGuid(),
            QuestionId = Questions[a.Index],
            Position = position + 1,
            OptionOrder = ["A", "B"],
            CorrectOptionIds = ["A"],
            SelectedOptionIds = a.AnsweredAt is null ? [] : [a.IsCorrect == false ? "B" : "A"],
            IsCorrect = a.IsCorrect,
            AnsweredAt = a.AnsweredAt
        }).ToList();
        return attempt;
    }

    public static (int Index, bool? IsCorrect, DateTime? AnsweredAt) Answer(int index, bool? isCorrect, DateTime? answeredAt) =>
        (index, isCorrect, answeredAt);
}
