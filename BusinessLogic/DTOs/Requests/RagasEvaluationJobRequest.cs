namespace BusinessLogic.DTOs.Requests;

public sealed record RagasEvaluationJobRequest(
    string EvaluationId,
    int UserId,
    int SubjectId,
    string SubjectName,
    IReadOnlyList<string> EmbeddingModels,
    IReadOnlyList<string> ChunkingStrategies,
    DateTimeOffset EnqueuedAt);
