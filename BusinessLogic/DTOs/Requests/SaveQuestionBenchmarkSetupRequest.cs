namespace BusinessLogic.DTOs.Requests;

public sealed record SaveQuestionBenchmarkSetupRequest(
    int QuestionId,
    bool IsAnswerable,
    IReadOnlyList<GoldChunkSelectionRequest> GoldChunks);

public sealed record GoldChunkSelectionRequest(
    int ChunkId,
    byte RelevanceGrade);