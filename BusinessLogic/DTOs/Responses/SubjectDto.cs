namespace BusinessLogic.DTOs.Responses;

public sealed record SubjectDto(
    int Id,
    string SubjectCode,
    string SubjectName,
    string? Description,
    int DocumentCount,
    int IndexedDocumentCount,
    int StudentCount,
    int TeacherCount,
    DateTime CreatedAt,
    int? CreatedById,
    string? CreatedByName,
    bool IsTeacherEnrolled,
    bool IsStudentEnrolled,
    bool CanManage,
    bool IsDeleted,
    DateTime? DeletedAt,
    string? DeleteReason,
    IReadOnlyList<string> TeacherNames,
    IReadOnlyList<string> MemberNames);
