using System;
using System.Collections.Generic;

namespace BusinessObject.Entities;

public partial class DocumentConflictCandidate
{
    public int Id { get; set; }

    public int ReviewId { get; set; }

    public int CandidateDocumentId { get; set; }

    public decimal MaxSimilarityScore { get; set; }

    public int FindingCount { get; set; }

    public string? Summary { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Document CandidateDocument { get; set; } = null!;

    public virtual ICollection<DocumentConflictFinding> Findings { get; set; } = new List<DocumentConflictFinding>();

    public virtual DocumentConflictReview Review { get; set; } = null!;
}
