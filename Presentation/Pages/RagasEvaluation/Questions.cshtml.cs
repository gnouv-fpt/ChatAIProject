using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Presentation.Models;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class QuestionsModel : AppPageModel
{
    private readonly IRagasEvaluationService _evaluationService;
    private readonly IEmbeddingModelRegistry _embeddingModelRegistry;

    public QuestionsModel(
        IRagasEvaluationService evaluationService,
        IEmbeddingModelRegistry embeddingModelRegistry)
    {
        _evaluationService = evaluationService;
        _embeddingModelRegistry = embeddingModelRegistry;
    }

    public RagasQuestionsViewModel ViewModel { get; set; } = new();

    public async Task OnGetAsync(int subjectId, CancellationToken cancellationToken)
    {
        var questions = await _evaluationService.GetQuestionsAsync(subjectId, cancellationToken);
        var readiness = await _evaluationService.GetBenchmarkReadinessAsync(subjectId, cancellationToken);
        ViewModel = new RagasQuestionsViewModel
        {
            SubjectId = subjectId,
            SubjectName = questions.FirstOrDefault()?.SubjectName ?? $"Môn học {subjectId}",
            EmbeddingModels = _embeddingModelRegistry.GetAvailableModels(benchmarkOnly: true)
                .Select(embeddingModel => new RagasEmbeddingModelOption
                {
                    Key = embeddingModel.Key,
                    Provider = embeddingModel.Provider,
                    Model = embeddingModel.Model,
                    IsSelected = embeddingModel.Enabled
                })
                .ToList(),
            Readiness = new BenchmarkReadinessViewModel
            {
                IsReady = readiness.IsReady,
                TotalQuestions = readiness.TotalQuestions,
                ReadyQuestions = readiness.ReadyQuestions,
                AnswerableQuestions = readiness.AnswerableQuestions,
                UnanswerableQuestions = readiness.UnanswerableQuestions,
                Errors = readiness.Errors.ToList()
            },
            ChunkingStrategies = _evaluationService.GetChunkingStrategies()
                .Select(strategy => new RagasChunkingStrategyOption
                {
                    Key = strategy.Key,
                    DisplayName = strategy.DisplayName,
                    Description = strategy.Description,
                    IsSelected = strategy.IsDefault
                })
                .ToList(),
            Questions = questions.Select(question => new RagasQuestionItem
            {
                Id = question.Id,
                Question = question.Question,
                GroundTruthAnswer = question.GroundTruthAnswer,
                IsAnswerable = question.IsAnswerable,
                IsBenchmarkReady = question.IsBenchmarkReady,
                GoldChunkCount = question.GoldChunkCount,
                CreatedByName = question.CreatedByName,
                CreatedAt = question.CreatedAt
            }).ToList()
        };
    }
}
