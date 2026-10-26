using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs;

public sealed class VerifyDocumentRequestDto
{
    [Required, Url]
    public string EvidenceUrl { get; set; } = "";
    public DateTime EffectiveDate { get; set; }
    public DateTime? ExpirationDate { get; set; }
    [Required, MinLength(20), MaxLength(2000)]
    public string ReviewNotes { get; set; } = "";
    [Range(typeof(bool), "true", "true", ErrorMessage = "Cần xác nhận đã đối chiếu hiệu lực và sửa đổi từng phần.")]
    public bool SourceAndAmendmentsReviewed { get; set; }
}
