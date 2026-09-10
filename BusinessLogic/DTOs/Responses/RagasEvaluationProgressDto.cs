namespace BusinessLogic.DTOs.Responses;

public sealed record RagasEvaluationProgressDto(
    string EvaluationId,
    int UserId,
    int SubjectId,
    string Stage,
    int Percent,
    int CompletedSteps,
    int TotalSteps,
    string? CurrentModel,
    string? CurrentStrategy,
    int? CurrentQuestion,
    int TotalQuestions,
    int ElapsedSeconds,
    int? EstimatedRemainingSeconds,
    string Message,
    bool IsCompleted = false,
    bool IsFailed = false);
