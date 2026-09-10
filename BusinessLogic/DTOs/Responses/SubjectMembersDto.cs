namespace BusinessLogic.DTOs.Responses;

public sealed record SubjectMembersDto(
    int SubjectId,
    string SubjectCode,
    string SubjectName,
    int? HeadTeacherId,
    string? HeadTeacherName,
    IReadOnlyList<SubjectMemberDto> Members,
    IReadOnlyList<SubjectMemberCandidateDto> Candidates);

public sealed record SubjectMemberDto(
    int? EnrollmentId,
    int UserId,
    string FullName,
    string Email,
    string RoleInClass,
    DateTime EnrolledAt,
    bool IsHeadTeacher);

public sealed record SubjectMemberCandidateDto(
    int UserId,
    string FullName,
    string Email,
    string Role);
