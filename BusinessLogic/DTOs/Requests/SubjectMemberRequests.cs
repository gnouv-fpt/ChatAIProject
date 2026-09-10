namespace BusinessLogic.DTOs.Requests;

public sealed record AddSubjectMemberRequestDto(
    int SubjectId,
    int UserId,
    string RoleInClass);

public sealed record ImportSubjectMembersRequestDto(
    int SubjectId,
    Stream FileStream,
    string FileName);
