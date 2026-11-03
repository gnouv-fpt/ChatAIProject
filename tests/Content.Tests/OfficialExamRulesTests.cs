using BusinessLogic.Exams;
using BusinessLogic.Exceptions;
using BusinessObject.Entities;
using Xunit;
using BankQuestion = BusinessObject.Entities.BankQuestion;

namespace Content.Tests;

public sealed class OfficialExamRulesTests
{
    private static ExamProfile Profile => new() { Id = OfficialExamRules.ClassBProfileId, Version = "1",
        QuestionCount = 30, DurationSeconds = 1200, PassCount = 27, FailOnCriticalWrong = true };

    [Fact]
    public void EffectiveWindowUsesVietnamMidnightAndNeverChangesPracticeRules()
    {
        OfficialExamRules.ValidateProfile(Profile, DateTimeOffset.Parse("2027-02-28T23:59:59+07:00"));
        Assert.Throws<ConflictException>(() => OfficialExamRules.ValidateProfile(Profile, DateTimeOffset.Parse("2027-03-01T00:00:00+07:00")));
        Assert.Throws<ConflictException>(() => OfficialExamRules.ValidateProfile(Profile, DateTimeOffset.Parse("2026-06-30T23:59:59+07:00")));
        OfficialExamRules.ValidateProfile(new() { Id = "practice", QuestionCount = 5, PassCount = 4 }, DateTimeOffset.Parse("2030-01-01Z"));
    }

    [Fact]
    public void OfficialPolicyCannotBeDowngradedOrInvented()
    {
        foreach (var profile in new[] { Profile with { PassCount = 24 }, Profile with { DurationSeconds = 1800 },
            Profile with { FailOnCriticalWrong = false }, Profile with { QuestionCount = 20 },
            Profile with { Id = "gplx-unverified" } })
            Assert.Throws<BadRequestException>(() => OfficialExamRules.ValidateProfile(profile));
    }

    [Fact]
    public void TemplateRequiresExactlyOneCriticalAndAllBContentGroups()
    {
        var questions = new List<BankQuestion>();
        foreach (var (kind, count) in new[] { ("RULES", 8), ("CULTURE", 1), ("DRIVING", 1), ("MECHANICS", 1), ("SIGN", 9), ("SCENARIO", 9) })
            for (var n = 0; n < count; n++) questions.Add(new() { Id = Guid.NewGuid(), CategoryType = kind });
        questions.Add(new() { Id = Guid.NewGuid(), CategoryType = "RULES", IsCritical = true });
        var bank = new ContentBank { Profile = Profile, Questions = questions };
        var ids = questions.Select(q => q.Id).ToArray();
        OfficialExamRules.ValidateTemplate(bank, ids, 20, 27);
        Assert.Throws<BadRequestException>(() => OfficialExamRules.ValidateTemplate(bank, ids, 30, 27));
        Assert.Throws<BadRequestException>(() => OfficialExamRules.ValidateTemplate(bank, ids, 20, 24));
        Assert.Throws<BadRequestException>(() => OfficialExamRules.ValidateTemplate(bank, ids.Skip(1).ToArray(), 20, 27));
        questions[0] = questions[0] with { IsCritical = true };
        Assert.Throws<BadRequestException>(() => OfficialExamRules.ValidateTemplate(bank, ids, 20, 27));
        questions[0] = questions[0] with { IsCritical = false, CategoryType = "SIGN" };
        Assert.Throws<BadRequestException>(() => OfficialExamRules.ValidateTemplate(bank, ids, 20, 27));
    }
}
