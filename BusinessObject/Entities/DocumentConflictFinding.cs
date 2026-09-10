using System;

namespace BusinessObject.Entities;

public partial class DocumentConflictFinding
{
    public int Id { get; set; }

    public int CandidateId { get; set; }

    public int NewChunkId { get; set; }

    public int ExistingChunkId { get; set; }

    public decimal SimilarityScore { get; set; }

    public decimal TextSimilarityScore { get; set; }

    public string Severity { get; set; } = null!;

    public string Explanation { get; set; } = null!;

    public string NewSnippet { get; set; } = null!;

    public string ExistingSnippet { get; set; } = null!;

    public DateTime CreatedAt { get; set; }

    public virtual DocumentConflictCandidate Candidate { get; set; } = null!;

    public virtual DocumentChunk ExistingChunk { get; set; } = null!;

    public virtual DocumentChunk NewChunk { get; set; } = null!;
}
