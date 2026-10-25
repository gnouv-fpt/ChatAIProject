using BusinessObject.Enums;

namespace BusinessObject.Entities;

// One row per bank version. A published version and its questions are immutable;
// changes are imported as a new version so graded attempts keep their original content.
public class QuestionBank
{
    public Guid Id { get; set; }

    public string Code { get; set; } = null!;

    public int Version { get; set; }

    public string Name { get; set; } = null!;

    public string? LicenseClass { get; set; }

    public string? Description { get; set; }

    public string? SourceName { get; set; }

    public string? SourceUrl { get; set; }

    // SHA-256 of the imported manifest, used to reject a re-import that changes a published version.
    public string ManifestHash { get; set; } = null!;

    public QuestionBankStatus Status { get; set; } = QuestionBankStatus.Draft;

    public int QuestionCount { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? PublishedAt { get; set; }

    public DateTime? RetiredAt { get; set; }

    public ICollection<Question> Questions { get; set; } = new List<Question>();

    public ICollection<ExamTemplate> ExamTemplates { get; set; } = new List<ExamTemplate>();
}
