using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IRagasBenchmarkResultRepository
{
    Task<IReadOnlyList<RagasBenchmarkResult>> GetByEvaluationQuestionIdsAsync(
        IEnumerable<int> evaluationQuestionIds,
        CancellationToken cancellationToken = default);

    Task AddRangeAsync(
        IEnumerable<RagasBenchmarkResult> results,
        CancellationToken cancellationToken = default);

    Task<int> CountBySubjectAsync(
        int subjectId,
        CancellationToken cancellationToken = default);

    Task<int> GetTotalAsync(CancellationToken cancellationToken = default);

    Task<RagasBenchmarkResult?> GetLatestBySubjectAsync(
        int subjectId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RagasBenchmarkResult>> GetLatestRunBySubjectAsync(
        int subjectId,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RagasBenchmarkResult>> GetRunBySubjectAsync(
        int subjectId,
        string runId,
        CancellationToken cancellationToken = default);

    Task<RagasBenchmarkRunPage> GetRunHistoryBySubjectAsync(
        int subjectId,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RagasBenchmarkResult>> GetBySubjectSinceAsync(
        int subjectId,
        DateTime sinceUtc,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RagasBenchmarkResult>> GetRecentAsync(
        int count,
        CancellationToken cancellationToken = default);
}

public sealed record RagasBenchmarkRunPage(
    IReadOnlyList<RagasBenchmarkRunAggregate> Items,
    int TotalCount);

public sealed record RagasBenchmarkRunAggregate(
    string RunId,
    DateTime RunDate,
    IReadOnlyList<string> EmbeddingModels,
    IReadOnlyList<string> ChunkingStrategies,
    int QuestionCount,
    decimal AvgRecallAt5);