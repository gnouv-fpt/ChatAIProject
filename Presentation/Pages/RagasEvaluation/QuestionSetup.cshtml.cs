using BusinessLogic.DTOs.Requests;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Models;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class QuestionSetupModel : AppPageModel
{
    private readonly IRagasEvaluationService _evaluationService;

    public QuestionSetupModel(IRagasEvaluationService evaluationService)
    {
        _evaluationService = evaluationService;
    }

    public RagasQuestionSetupViewModel ViewModel { get; set; } = new();

    [BindProperty]
    public RagasQuestionSetupInputModel Input { get; set; } = new();

    [BindProperty(SupportsGet = true)]
    public string? SearchTerm { get; set; }

    public async Task<IActionResult> OnGetAsync(
        int id,
        CancellationToken cancellationToken)
    {
        var setup = await _evaluationService.GetQuestionSetupAsync(id, cancellationToken);
        if (setup is null)
        {
            return RedirectToPage("/RagasEvaluation/Index");
        }

        var candidates = await _evaluationService.SuggestGoldChunksAsync(
            id,
            SearchTerm,
            cancellationToken);

        ViewModel = new RagasQuestionSetupViewModel
        {
            QuestionId = setup.Id,
            SubjectId = setup.SubjectId,
            SubjectName = setup.SubjectName,
            Question = setup.Question,
            GroundTruthAnswer = setup.GroundTruthAnswer,
            IsAnswerable = setup.IsAnswerable,
            IsBenchmarkReady = setup.IsBenchmarkReady,
            SearchTerm = SearchTerm,
            Candidates = candidates.Select(MapCandidate).ToList()
        };

        Input = new RagasQuestionSetupInputModel
        {
            QuestionId = setup.Id,
            IsAnswerable = setup.IsAnswerable,
            Candidates = ViewModel.Candidates.Select(candidate => new RagasChunkSelectionInputModel
            {
                ChunkId = candidate.ChunkId,
                IsSelected = candidate.IsSelected,
                RelevanceGrade = candidate.RelevanceGrade
            }).ToList()
        };

        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        var selections = Input.Candidates
            .Where(candidate => candidate.IsSelected)
            .Select(candidate => new GoldChunkSelectionRequest(
                candidate.ChunkId,
                candidate.RelevanceGrade))
            .ToList();

        var result = await _evaluationService.SaveQuestionBenchmarkSetupAsync(
            new SaveQuestionBenchmarkSetupRequest(
                Input.QuestionId,
                Input.IsAnswerable,
                selections),
            cancellationToken);

        TempData[result.Succeeded ? "SuccessMessage" : "ErrorMessage"] = result.Message;
        if (!result.Succeeded)
        {
            return RedirectToPage(new { id = Input.QuestionId });
        }

        var setup = await _evaluationService.GetQuestionSetupAsync(
            Input.QuestionId,
            cancellationToken);
        return setup is null
            ? RedirectToPage("/RagasEvaluation/Index")
            : RedirectToPage("/RagasEvaluation/Questions", new { subjectId = setup.SubjectId });
    }

    private static RagasChunkCandidateViewModel MapCandidate(
        BusinessLogic.DTOs.Responses.BenchmarkChunkCandidateDto candidate)
    {
        return new RagasChunkCandidateViewModel
        {
            ChunkId = candidate.ChunkId,
            DocumentTitle = candidate.DocumentTitle,
            OriginalFileName = candidate.OriginalFileName,
            ChunkIndex = candidate.ChunkIndex,
            PageNumber = candidate.PageNumber,
            SlideNumber = candidate.SlideNumber,
            Content = candidate.Content,
            SuggestionScore = candidate.SuggestionScore,
            IsSelected = candidate.IsSelected,
            RelevanceGrade = candidate.RelevanceGrade ?? 2
        };
    }
}