namespace BusinessObject.Entities;

public class DocumentChunk
{
    public Guid Id { get; set; }

    public Guid DocumentId { get; set; }

    public string? Chapter { get; set; }

    public string? Article { get; set; }

    public string? Clause { get; set; }

    public string Content { get; set; } = null!;

    public int TokenCount { get; set; }

    public string? VectorId { get; set; }

    public bool IsVerified { get; set; }

    public LegalDocument Document { get; set; } = null!;

    public ICollection<Citation> Citations { get; set; } = new List<Citation>();
}
