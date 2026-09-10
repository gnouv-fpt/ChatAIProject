using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class DetailsModel : AppPageModel
{
    private readonly IRagasEvaluationService _evaluationService;

    public DetailsModel(IRagasEvaluationService evaluationService)
    {
        _evaluationService = evaluationService;
    }

    public RagasRunResultViewModel ViewModel { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(
        int subjectId,
        string? runId,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(runId))
        {
            return RedirectToPage("/RagasEvaluation/History", new { subjectId });
        }

        var result = await _evaluationService.GetRunAsync(
            subjectId,
            runId,
            cancellationToken);
        if (result is null)
        {
            TempData["ErrorMessage"] = "Không tìm thấy lần benchmark đã chọn.";
            return RedirectToPage("/RagasEvaluation/History", new { subjectId });
        }

        var detailItems = result.Results.Select(item => new RagasResultDetailItem
        {
            EmbeddingModel = item.EmbeddingModel,
            ChunkingStrategy = item.ChunkingStrategy,
            Question = item.Question,
            GroundTruthAnswer = item.GroundTruthAnswer,
            GeneratedAnswer = item.GeneratedAnswer,
            IsAnswerable = item.IsAnswerable,
            RetrievedChunkIds = item.RetrievedChunkIds,
            CitationChunkIds = item.CitationChunkIds,
            RecallAt5 = item.RecallAt5,
            MrrAt10 = item.MrrAt10,
            NdcgAt5 = item.NdcgAt5,
            AnswerCorrectness = item.AnswerCorrectness,
            Faithfulness = item.Faithfulness,
            CitationPrecision = item.CitationPrecision,
            CitationRecall = item.CitationRecall,
            CitationF1 = item.CitationF1,
            ExpectedNoAnswer = item.ExpectedNoAnswer,
            PredictedNoAnswer = item.PredictedNoAnswer,
            EmbeddingLatencyMs = item.EmbeddingLatencyMs,
            RetrievalLatencyMs = item.RetrievalLatencyMs,
            GenerationLatencyMs = item.GenerationLatencyMs,
            EndToEndLatencyMs = item.EndToEndLatencyMs
        }).ToList();

        ViewModel = new RagasRunResultViewModel
        {
            SubjectId = result.SubjectId,
            SubjectName = result.SubjectName,
            RunId = result.RunId,
            EmbeddingModel = result.EmbeddingModel,
            LlmModel = result.LlmModel,
            ChunkingStrategy = result.ChunkingStrategy,
            QuestionCount = result.QuestionCount,
            AvgRecallAt5 = result.AvgRecallAt5,
            AvgMrrAt10 = result.AvgMrrAt10,
            AvgNdcgAt5 = result.AvgNdcgAt5,
            AvgAnswerCorrectness = result.AvgAnswerCorrectness,
            AvgFaithfulness = result.AvgFaithfulness,
            AvgCitationF1 = result.AvgCitationF1,
            NoAnswerF1 = result.NoAnswerF1,
            EndToEndLatencyP50Ms = result.EndToEndLatencyP50Ms,
            EndToEndLatencyP95Ms = result.EndToEndLatencyP95Ms,
            RunDate = result.RunDate,
            ModelSummaries = result.ModelSummaries.Select(summary => new RagasModelSummaryItem
            {
                EmbeddingModel = summary.EmbeddingModel,
                LlmModel = summary.LlmModel,
                VectorStore = summary.VectorStore,
                ChunkingStrategy = summary.ChunkingStrategy,
                QuestionCount = summary.QuestionCount,
                AvgRecallAt5 = summary.AvgRecallAt5,
                AvgMrrAt10 = summary.AvgMrrAt10,
                AvgNdcgAt5 = summary.AvgNdcgAt5,
                AvgAnswerCorrectness = summary.AvgAnswerCorrectness,
                AvgFaithfulness = summary.AvgFaithfulness,
                AvgCitationF1 = summary.AvgCitationF1,
                NoAnswerF1 = summary.NoAnswerF1,
                EmbeddingLatencyP50Ms = summary.EmbeddingLatencyP50Ms,
                EmbeddingLatencyP95Ms = summary.EmbeddingLatencyP95Ms,
                RetrievalLatencyP50Ms = summary.RetrievalLatencyP50Ms,
                RetrievalLatencyP95Ms = summary.RetrievalLatencyP95Ms,
                EndToEndLatencyP50Ms = summary.EndToEndLatencyP50Ms,
                EndToEndLatencyP95Ms = summary.EndToEndLatencyP95Ms
            }).ToList(),
            WeeklyTokenUsage = result.WeeklyTokenUsage.Select(summary => new RagasTokenUsageSummaryItem
            {
                EmbeddingModel = summary.EmbeddingModel,
                LlmModel = summary.LlmModel,
                RunCount = summary.RunCount,
                QuestionCount = summary.QuestionCount,
                EstimatedEmbeddingTokens = summary.EstimatedEmbeddingTokens,
                EstimatedPromptTokens = summary.EstimatedPromptTokens,
                EstimatedCompletionTokens = summary.EstimatedCompletionTokens,
                EstimatedTotalTokens = summary.EstimatedTotalTokens,
                AvgRecallAt5 = summary.AvgRecallAt5,
                FromUtc = summary.FromUtc,
                ToUtc = summary.ToUtc
            }).ToList(),
            Results = detailItems,
            ResultGroups = detailItems
                .GroupBy(item => item.EmbeddingModel, StringComparer.OrdinalIgnoreCase)
                .OrderBy(group => group.Key)
                .Select(group => new RagasModelResultGroupViewModel
                {
                    EmbeddingModel = group.Key,
                    ChunkingStrategies = group
                        .Select(item => item.ChunkingStrategy)
                        .Distinct(StringComparer.OrdinalIgnoreCase)
                        .OrderBy(strategy => strategy)
                        .ToList(),
                    Results = group
                        .OrderBy(item => item.ChunkingStrategy)
                        .ThenBy(item => item.Question)
                        .ToList()
                })
                .ToList()
        };

        return Page();
    }
}
