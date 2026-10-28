using System.ComponentModel.DataAnnotations;
using BusinessObject.Entities;

namespace BusinessLogic.DTOs;

// Transport contract only. Shared SQL entities/columns remain owned by Vuong at P0.
public sealed class ContentManifestRequestDto
{
    [Required(ErrorMessage = "Thiếu gói ngân hàng câu hỏi.")]
    public QuestionBank Bank { get; set; } = null!;
    public List<QuestionAnimationDto> Animations { get; set; } = [];
}

public sealed record QuestionAnimationDto(Guid QuestionId, string ExplanationAnimationUrl);
public sealed record ContentValidationIssueDto(string Path, string Message);
public sealed record ContentManifestPreviewDto(string? ManifestHash, int QuestionCount,
    int AnimationCount, IReadOnlyList<ContentValidationIssueDto> Issues)
{
    public bool CanImport => Issues.Count == 0;
}

public sealed record ContentCapabilitiesDto(bool CanPreviewManifest, bool CanPreviewLegalSource,
    bool CanPersistBank, string PersistenceStatus, IReadOnlyList<string> AnimationAllowedHosts);

public sealed class CrawlPreviewRequestDto
{
    [Required(ErrorMessage = "Thiếu URL nguồn."), Url(ErrorMessage = "URL nguồn không hợp lệ.")]
    public string SourceUrl { get; set; } = "";
}

public sealed record LegalSourceEvidenceDto(string SourceUrl, DateTime RetrievedAtUtc, string HtmlSha256,
    string ContentSha256, string DocumentNumber, string Title, string Content,
    IReadOnlyList<LegalChunkPreviewDto> Chunks);
public sealed record LegalChunkPreviewDto(int Sequence, string? Article, string? Clause, string? Point, string Content);
