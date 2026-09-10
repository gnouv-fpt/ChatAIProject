using BusinessObject.Entities;

namespace DataAccess.Repositories.Interfaces;

public interface IEvaluationQuestionGoldChunkRepository
{
    Task<IReadOnlyList<EvaluationQuestionGoldChunk>> GetByQuestionAsync(
        int evaluationQuestionId,
        CancellationToken cancellationToken = default);

    Task SaveSetupAsync(
        EvaluationQuestion question,
        IReadOnlyList<EvaluationQuestionGoldChunk> goldChunks,
        CancellationToken cancellationToken = default);
}