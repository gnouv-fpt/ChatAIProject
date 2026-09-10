using System;
using System.Collections.Generic;

namespace BusinessObject.Entities;

public partial class DocumentConflictReview
{
    public int Id { get; set; }

    public int SubjectId { get; set; }

    public int NewDocumentId { get; set; }

    public string Status { get; set; } = null!;

    public string Summary { get; set; } = null!;

    public decimal HighestSimilarityScore { get; set; }

    public int FindingCount { get; set; }

    public string? ResolutionChoice { get; set; }

    public int? ResolvedBy { get; set; }

    public DateTime? ResolvedAt { get; set; }

    public string? ResolutionNote { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual ICollection<DocumentConflictCandidate> Candidates { get; set; } = new List<DocumentConflictCandidate>();

    public virtual Document NewDocument { get; set; } = null!;

    public virtual User? ResolvedByNavigation { get; set; }

    public virtual Subject Subject { get; set; } = null!;
}
