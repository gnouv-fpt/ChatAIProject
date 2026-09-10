namespace BusinessLogic.DTOs.Responses;

public sealed record SubjectRealtimeEventDto(
    string Action,
    int SubjectId,
    DateTime OccurredAt,
    string Message);
