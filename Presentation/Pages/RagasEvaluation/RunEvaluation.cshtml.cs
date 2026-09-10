using BusinessLogic.DTOs.Requests;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Hubs;

namespace Presentation.Pages.RagasEvaluation;

[Authorize(Roles = "Admin")]
public sealed class RunEvaluationModel : AppPageModel
{
    private readonly IRagasEvaluationService _evaluationService;
    private readonly IEmbeddingModelRegistry _embeddingModelRegistry;
    private readonly IRagasEvaluationJobQueue _jobQueue;
    private readonly ILogger<RunEvaluationModel> _logger;

    public RunEvaluationModel(
        IRagasEvaluationService evaluationService,
        IEmbeddingModelRegistry embeddingModelRegistry,
        IRagasEvaluationJobQueue jobQueue,
        ILogger<RunEvaluationModel> logger)
    {
        _evaluationService = evaluationService;
        _embeddingModelRegistry = embeddingModelRegistry;
        _jobQueue = jobQueue;
        _logger = logger;
    }

    public async Task<IActionResult> OnPostAsync(
        [FromBody] RunEvaluationRequest request,
        CancellationToken cancellationToken)
    {
        var userId = GetCurrentUserId();
        if (userId <= 0
            || request is null
            || !RagasEvaluationProgressGroups.IsValidEvaluationId(request.EvaluationId))
        {
            return BadRequestJson("Phiên đánh giá không hợp lệ. Vui lòng tải lại trang và thử lại.");
        }

        var embeddingModels = request.EmbeddingModels
            .Where(model => !string.IsNullOrWhiteSpace(model))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        var chunkingStrategies = request.ChunkingStrategies
            .Where(strategy => !string.IsNullOrWhiteSpace(strategy))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (embeddingModels.Count == 0)
        {
            return BadRequestJson("Vui lòng chọn ít nhất một embedding model để benchmark.");
        }

        if (chunkingStrategies.Count == 0)
        {
            return BadRequestJson("Vui lòng chọn ít nhất một chunking strategy để benchmark.");
        }

        try
        {
            var availableModelKeys = _embeddingModelRegistry
                .GetAvailableModels(benchmarkOnly: true)
                .Select(model => model.Key)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            if (embeddingModels.Any(model => !availableModelKeys.Contains(model)))
            {
                return BadRequestJson("Danh sách embedding model không hợp lệ hoặc model đã bị tắt.");
            }

            var availableStrategies = _evaluationService
                .GetChunkingStrategies()
                .Select(strategy => strategy.Key)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);
            if (chunkingStrategies.Any(strategy => !availableStrategies.Contains(strategy)))
            {
                return BadRequestJson("Danh sách strategy không hợp lệ.");
            }

            var readiness = await _evaluationService.GetBenchmarkReadinessAsync(
                request.SubjectId,
                cancellationToken);
            if (!readiness.IsReady)
            {
                var message = readiness.Errors.Count > 0
                    ? string.Join(" ", readiness.Errors)
                    : "Test set chưa sẵn sàng để chạy benchmark.";
                return BadRequestJson(message);
            }

            var questions = await _evaluationService.GetQuestionsAsync(
                request.SubjectId,
                cancellationToken);
            var subjectName = questions.FirstOrDefault()?.SubjectName ?? $"Môn học {request.SubjectId}";

            var status = await _jobQueue.EnqueueAsync(
                new RagasEvaluationJobRequest(
                    request.EvaluationId,
                    userId,
                    request.SubjectId,
                    subjectName,
                    embeddingModels,
                    chunkingStrategies,
                    DateTimeOffset.UtcNow),
                cancellationToken);

            return new JsonResult(new
            {
                success = true,
                accepted = true,
                evaluationId = status.EvaluationId,
                subjectId = status.SubjectId,
                status
            })
            {
                StatusCode = StatusCodes.Status202Accepted
            };
        }
        catch (InvalidOperationException exception)
        {
            _logger.LogWarning(
                exception,
                "RAG evaluation could not be queued for subject {SubjectId}",
                request.SubjectId);

            return BadRequestJson(exception.Message);
        }
        catch (Exception exception)
        {
            _logger.LogError(
                exception,
                "Unexpected error while queueing RAG evaluation for subject {SubjectId}",
                request.SubjectId);

            return new JsonResult(new
            {
                success = false,
                message = "Không thể đưa đánh giá vào hàng đợi. Vui lòng kiểm tra cấu hình Gemini, embedding và log hệ thống."
            })
            {
                StatusCode = StatusCodes.Status500InternalServerError
            };
        }
    }

    public async Task<IActionResult> OnGetStatusAsync(
        string evaluationId,
        CancellationToken cancellationToken)
    {
        var userId = GetCurrentUserId();
        if (userId <= 0 || !RagasEvaluationProgressGroups.IsValidEvaluationId(evaluationId))
        {
            return BadRequestJson("Phiên đánh giá không hợp lệ.");
        }

        var status = await _jobQueue.GetStatusAsync(userId, evaluationId, cancellationToken);
        return status is null
            ? new JsonResult(new { success = false, message = "Không tìm thấy phiên đánh giá." })
            {
                StatusCode = StatusCodes.Status404NotFound
            }
            : new JsonResult(new { success = true, status });
    }

    public async Task<IActionResult> OnGetCurrentAsync(CancellationToken cancellationToken)
    {
        var userId = GetCurrentUserId();
        if (userId <= 0)
        {
            return BadRequestJson("Không xác định được tài khoản hiện tại.");
        }

        var jobs = await _jobQueue.GetUserJobsAsync(userId, cancellationToken);
        return new JsonResult(new { success = true, jobs });
    }

    private static JsonResult BadRequestJson(string message)
    {
        return new JsonResult(new { success = false, message })
        {
            StatusCode = StatusCodes.Status400BadRequest
        };
    }
}

public sealed class RunEvaluationRequest
{
    public string EvaluationId { get; set; } = string.Empty;

    public int SubjectId { get; set; }

    public List<string> EmbeddingModels { get; set; } = new();

    public List<string> ChunkingStrategies { get; set; } = new();
}
