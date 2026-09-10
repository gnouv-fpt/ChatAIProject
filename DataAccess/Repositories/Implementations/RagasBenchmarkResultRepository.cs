using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class RagasBenchmarkResultRepository : IRagasBenchmarkResultRepository
{
    private readonly ChatAIWebDbContext _context;

    public RagasBenchmarkResultRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<RagasBenchmarkResult>> GetByEvaluationQuestionIdsAsync(
        IEnumerable<int> evaluationQuestionIds,
        CancellationToken cancellationToken = default)
    {
        var ids = evaluationQuestionIds.Distinct().ToList();
        if (ids.Count == 0)
        {
            return [];
        }

        return await CreateReadQuery()
            .Where(result => ids.Contains(result.EvaluationQuestionId))
            .OrderByDescending(result => result.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task AddRangeAsync(
        IEnumerable<RagasBenchmarkResult> results,
        CancellationToken cancellationToken = default)
    {
        await _context.RagasBenchmarkResults.AddRangeAsync(results, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);
    }

    public Task<int> CountBySubjectAsync(
        int subjectId,
        CancellationToken cancellationToken = default)
    {
        return _context.RagasBenchmarkResults
            .AsNoTracking()
            .Where(result => result.EvaluationQuestion.SubjectId == subjectId)
            .Select(result => result.RunId)
            .Distinct()
            .CountAsync(cancellationToken);
    }

    public Task<int> GetTotalAsync(CancellationToken cancellationToken = default)
    {
        return _context.RagasBenchmarkResults
            .AsNoTracking()
            .Select(result => result.RunId)
            .Distinct()
            .CountAsync(cancellationToken);
    }

    public Task<RagasBenchmarkResult?> GetLatestBySubjectAsync(
        int subjectId,
        CancellationToken cancellationToken = default)
    {
        return CreateReadQuery()
            .Where(result => result.EvaluationQuestion.SubjectId == subjectId)
            .OrderByDescending(result => result.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<RagasBenchmarkResult>> GetLatestRunBySubjectAsync(
        int subjectId,
        CancellationToken cancellationToken = default)
    {
        var runId = await _context.RagasBenchmarkResults
            .AsNoTracking()
            .Where(result => result.EvaluationQuestion.SubjectId == subjectId)
            .OrderByDescending(result => result.CreatedAt)
            .Select(result => result.RunId)
            .FirstOrDefaultAsync(cancellationToken);

        return string.IsNullOrWhiteSpace(runId)
            ? []
            : await GetRunBySubjectAsync(subjectId, runId, cancellationToken);
    }

    public async Task<IReadOnlyList<RagasBenchmarkResult>> GetRunBySubjectAsync(
        int subjectId,
        string runId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(runId))
        {
            return [];
        }

        return await CreateReadQuery()
            .Where(result =>
                result.EvaluationQuestion.SubjectId == subjectId
                && result.RunId == runId)
            .OrderBy(result => result.EmbeddingModel)
            .ThenBy(result => result.ChunkingStrategy)
            .ThenBy(result => result.EvaluationQuestionId)
            .ToListAsync(cancellationToken);
    }

    public async Task<RagasBenchmarkRunPage> GetRunHistoryBySubjectAsync(
        int subjectId,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _context.RagasBenchmarkResults
            .AsNoTracking()
            .Where(result => result.EvaluationQuestion.SubjectId == subjectId);

        var totalCount = await query
            .Select(result => result.RunId)
            .Distinct()
            .CountAsync(cancellationToken);

        var runRows = await query
            .GroupBy(result => result.RunId)
            .Select(group => new
            {
                RunId = group.Key,
                RunDate = group.Max(result => result.CreatedAt),
                QuestionCount = group
                    .Select(result => result.EvaluationQuestionId)
                    .Distinct()
                    .Count(),
                AvgRecallAt5 = group
                    .Where(result => !result.ExpectedNoAnswer)
                    .Average(result => result.RecallAt5 ?? 0)
            })
            .OrderByDescending(run => run.RunDate)
            .ThenByDescending(run => run.RunId)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var runIds = runRows.Select(run => run.RunId).ToList();
        var metadata = runIds.Count == 0
            ? []
            : await query
                .Where(result => runIds.Contains(result.RunId))
                .Select(result => new
                {
                    result.RunId,
                    result.EmbeddingModel,
                    result.ChunkingStrategy
                })
                .Distinct()
                .ToListAsync(cancellationToken);

        var items = runRows.Select(run => new RagasBenchmarkRunAggregate(
            run.RunId,
            run.RunDate,
            metadata
                .Where(item => item.RunId == run.RunId)
                .Select(item => item.EmbeddingModel)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(model => model)
                .ToList(),
            metadata
                .Where(item => item.RunId == run.RunId)
                .Select(item => item.ChunkingStrategy)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(strategy => strategy)
                .ToList(),
            run.QuestionCount,
            run.AvgRecallAt5))
            .ToList();

        return new RagasBenchmarkRunPage(items, totalCount);
    }

    public async Task<IReadOnlyList<RagasBenchmarkResult>> GetBySubjectSinceAsync(
        int subjectId,
        DateTime sinceUtc,
        CancellationToken cancellationToken = default)
    {
        return await CreateReadQuery()
            .Where(result =>
                result.EvaluationQuestion.SubjectId == subjectId
                && result.CreatedAt >= sinceUtc)
            .OrderByDescending(result => result.CreatedAt)
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<RagasBenchmarkResult>> GetRecentAsync(
        int count,
        CancellationToken cancellationToken = default)
    {
        return await CreateReadQuery()
            .OrderByDescending(result => result.CreatedAt)
            .Take(Math.Clamp(count, 1, 100))
            .ToListAsync(cancellationToken);
    }

    private IQueryable<RagasBenchmarkResult> CreateReadQuery()
    {
        return _context.RagasBenchmarkResults
            .AsNoTracking()
            .Include(result => result.EvaluationQuestion)
                .ThenInclude(question => question.Subject);
    }
}