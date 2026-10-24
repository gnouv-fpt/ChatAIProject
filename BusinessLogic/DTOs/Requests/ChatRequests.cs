using System.ComponentModel.DataAnnotations;

namespace BusinessLogic.DTOs.Requests;

public class CreateChatSessionRequest
{
    [MaxLength(200, ErrorMessage = "Tiêu đề không được vượt quá 200 ký tự.")]
    public string? Title { get; set; }
}

public class SendMessageRequest
{
    public Guid RequestId { get; set; }

    [MaxLength(3, ErrorMessage = "Mỗi câu hỏi được đính kèm tối đa 3 ảnh.")]
    public Guid[] AttachmentIds { get; set; } = [];
    public bool UsePreviousAttachments { get; set; } = true;

    [Required(ErrorMessage = "Nội dung câu hỏi không được để trống.")]
    [StringLength(2000, MinimumLength = 1, ErrorMessage = "Câu hỏi phải từ 1 đến 2000 ký tự.")]
    public string Prompt { get; set; } = string.Empty;
}
