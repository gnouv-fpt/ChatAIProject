using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace DataAccess.Repositories.Implementations;

public sealed class EvaluationQuestionGoldChunkRepository : IEvaluationQuestionGoldChunkRepository
{
    private readonly ChatAIWebDbContext _context;

    public EvaluationQuestionGoldChunkRepository(ChatAIWebDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<EvaluationQuestionGoldChunk>> GetByQuestionAsync(
        int evaluationQuestionId,
        CancellationToken cancellationToken = default)
    {
        return await _context.EvaluationQuestionGoldChunks
            .AsNoTracking()
            .Include(item => item.DocumentChunk)
                .ThenInclude(chunk => chunk.Document)
            .Where(item => item.EvaluationQuestionId == evaluationQuestionId)
            .OrderByDescending(item => item.RelevanceGrade)
            .ThenBy(item => item.DocumentChunk.DocumentId)
            .ThenBy(item => item.DocumentChunk.ChunkIndex)
            .ToListAsync(cancellationToken);
    }

    public async Task SaveSetupAsync(
        EvaluationQuestion question,
        IReadOnlyList<EvaluationQuestionGoldChunk> goldChunks,
        CancellationToken cancellationToken = default)
    {
        await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
        var existing = await _context.EvaluationQuestionGoldChunks
            .Where(item => item.EvaluationQuestionId == question.Id)
            .ToListAsync(cancellationToken);

        _context.EvaluationQuestions.Update(question);
        _context.EvaluationQuestionGoldChunks.RemoveRange(existing);
        if (goldChunks.Count > 0)
        {
            await _context.EvaluationQuestionGoldChunks.AddRangeAsync(goldChunks, cancellationToken);
        }

        await _context.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
    }
}