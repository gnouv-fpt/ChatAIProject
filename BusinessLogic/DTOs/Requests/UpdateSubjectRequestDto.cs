namespace BusinessLogic.DTOs.Requests;

public sealed record UpdateSubjectRequestDto(
    int Id,
    string SubjectCode,
    string SubjectName,
    string? Description,
    int? HeadTeacherId = null);
