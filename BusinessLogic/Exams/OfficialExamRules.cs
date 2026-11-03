using BusinessLogic.Exceptions;
using BusinessObject.Entities;

namespace BusinessLogic.Exams;

// Phụ lục IV.A TT12/2025, retained through 28/02/2027 by TT108/2026 Điều 41(6).
// Keep the serialized ExamProfile contract unchanged so existing package hashes remain valid.
public static class OfficialExamRules
{
    public const string ClassBProfileId = "gplx-B-tt12-2025-until-2027-02-28";
    public static bool IsOfficial(ExamProfile profile) => profile.Id.StartsWith("gplx-", StringComparison.Ordinal);

    public static void ValidateProfile(ExamProfile profile, DateTimeOffset? now = null)
    {
        if (!IsOfficial(profile)) return;
        if (profile.Id != ClassBProfileId || profile.Version != "1" || profile.QuestionCount != 30 ||
            profile.DurationSeconds != 1200 || profile.PassCount != 27 || !profile.FailOnCriticalWrong)
            throw new BadRequestException("Profile sát hạch hạng B phải có 30 câu, 20 phút, đạt 27 câu và không sai câu điểm liệt.");
        var current = now ?? DateTimeOffset.UtcNow;
        if (current < new DateTimeOffset(2026, 7, 1, 0, 0, 0, TimeSpan.FromHours(7)) ||
            current >= new DateTimeOffset(2027, 3, 1, 0, 0, 0, TimeSpan.FromHours(7)))
            throw new ConflictException("Profile hạng B này hết phạm vi áp dụng. Cần đối chiếu quy định và ấn bản mới trước khi tạo bài thi.");
    }

    public static void ValidateTemplate(ContentBank bank, IReadOnlyCollection<Guid> ids, int minutes, int passCount)
    {
        if (!IsOfficial(bank.Profile)) return;
        ValidateProfile(bank.Profile);
        var selected = bank.Questions.Where(q => ids.Contains(q.Id)).ToArray();
        var expected = new Dictionary<string, int> { ["RULES"] = 8, ["CULTURE"] = 1,
            ["DRIVING"] = 1, ["MECHANICS"] = 1, ["SIGN"] = 9, ["SCENARIO"] = 9 };
        if (ids.Count != 30 || selected.Length != 30 || minutes != 20 || passCount != 27 ||
            selected.Count(q => q.IsCritical) != 1 || expected.Any(pair =>
                selected.Count(q => q.CategoryType == pair.Key && !q.IsCritical) != pair.Value))
            throw new BadRequestException("Đề hạng B phải đúng cấu trúc CV2262: 30 câu, đúng một câu điểm liệt, 20 phút, điểm đạt 27.");
    }
}
