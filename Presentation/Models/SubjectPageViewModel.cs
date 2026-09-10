using System.ComponentModel.DataAnnotations;

namespace Presentation.Models;

public sealed class SubjectPageViewModel
{
    public IReadOnlyList<SubjectViewModel> Subjects { get; set; } = [];

    public bool IsAdmin { get; set; }

    public string StatusFilter { get; set; } = "active";
}

public sealed class SubjectViewModel
{
    public int Id { get; set; }
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int DocumentCount { get; set; }
    public int IndexedDocumentCount { get; set; }
    public int StudentCount { get; set; }
    public int TeacherCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public int? CreatedById { get; set; }
    public string? CreatedByName { get; set; }
    public bool IsTeacherEnrolled { get; set; }
    public bool CanManage { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }
    public string? DeleteReason { get; set; }
    public IReadOnlyList<string> TeacherNames { get; set; } = [];
    public IReadOnlyList<string> MemberNames { get; set; } = [];
}

public sealed class CreateSubjectViewModel
{
    [Required(ErrorMessage = "Mã môn học là bắt buộc.")]
    [StringLength(50, ErrorMessage = "Mã môn học không được vượt quá 50 ký tự.")]
    [Display(Name = "Mã môn học")]
    public string SubjectCode { get; set; } = string.Empty;

    [Required(ErrorMessage = "Tên môn học là bắt buộc.")]
    [StringLength(200, ErrorMessage = "Tên môn học không được vượt quá 200 ký tự.")]
    [Display(Name = "Tên môn học")]
    public string SubjectName { get; set; } = string.Empty;

    [StringLength(2000, ErrorMessage = "Mô tả không được vượt quá 2000 ký tự.")]
    [Display(Name = "Mô tả")]
    public string? Description { get; set; }

    [Display(Name = "Trưởng bộ môn")]
    public int? HeadTeacherId { get; set; }

    public IReadOnlyList<SubjectMemberCandidateViewModel> TeacherOptions { get; set; } = [];
}

public sealed class EditSubjectViewModel
{
    public int Id { get; set; }

    [Required(ErrorMessage = "Mã môn học là bắt buộc.")]
    [StringLength(50, ErrorMessage = "Mã môn học không được vượt quá 50 ký tự.")]
    [Display(Name = "Mã môn học")]
    public string SubjectCode { get; set; } = string.Empty;

    [Required(ErrorMessage = "Tên môn học là bắt buộc.")]
    [StringLength(200, ErrorMessage = "Tên môn học không được vượt quá 200 ký tự.")]
    [Display(Name = "Tên môn học")]
    public string SubjectName { get; set; } = string.Empty;

    [StringLength(2000, ErrorMessage = "Mô tả không được vượt quá 2000 ký tự.")]
    [Display(Name = "Mô tả")]
    public string? Description { get; set; }

    [Display(Name = "Trưởng bộ môn")]
    public int? HeadTeacherId { get; set; }

    public IReadOnlyList<SubjectMemberCandidateViewModel> TeacherOptions { get; set; } = [];
}

public sealed class SubjectMembersViewModel
{
    public int SubjectId { get; set; }
    public string SubjectCode { get; set; } = string.Empty;
    public string SubjectName { get; set; } = string.Empty;
    public int? HeadTeacherId { get; set; }
    public string? HeadTeacherName { get; set; }
    public AddSubjectMemberViewModel AddMember { get; set; } = new();
    public IReadOnlyList<SubjectMemberViewModel> Members { get; set; } = [];
    public IReadOnlyList<SubjectMemberCandidateViewModel> Candidates { get; set; } = [];
}

public sealed class SubjectMemberViewModel
{
    public int? EnrollmentId { get; set; }
    public int UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string RoleInClass { get; set; } = string.Empty;
    public DateTime EnrolledAt { get; set; }
    public bool IsHeadTeacher { get; set; }
}

public sealed class SubjectMemberCandidateViewModel
{
    public int UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
}

public sealed class AddSubjectMemberViewModel
{
    [Required(ErrorMessage = "Vui lòng chọn người dùng.")]
    public int UserId { get; set; }

    [Required(ErrorMessage = "Vui lòng chọn role.")]
    public string RoleInClass { get; set; } = "Student";
}
