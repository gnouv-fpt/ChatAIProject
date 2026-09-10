using BusinessLogic.Services.Interfaces;
using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using BusinessLogic.DTOs.Requests;
using BusinessLogic.DTOs.Responses;
using BusinessLogic.Infrastructure;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Infrastructure.Implementations;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class RagasEvaluationService : IRagasEvaluationService
{
    private const int Phase4QuestionTarget = 50;
    private const string NotFoundAnswer = "Không tìm thấy thông tin này trong tài liệu đã tải lên.";

    private readonly ISubjectRepository _subjectRepository;
    private readonly IEvaluationQuestionRepository _questionRepository;
    private readonly IEvaluationQuestionGoldChunkRepository _goldChunkRepository;
    private readonly IDocumentChunkRepository _documentChunkRepository;
    private readonly IRagasBenchmarkResultRepository _resultRepository;
    private readonly IEmbeddingModelRegistry _embeddingModelRegistry;
    private readonly IEmbeddingBackfillService _backfillService;
    private readonly IVectorSearchService _vectorSearchService;
    private readonly IRagasEvaluatorClient _ragasEvaluatorClient;
    private readonly ILlmService _llmService;
    private readonly PromptBuilder _promptBuilder;
    private readonly ISystemSettingsService _settingsService;
    private readonly IRagasEvaluationProgressReporter _progressReporter;
    private readonly IBenchmarkMetricCalculator _metricCalculator;
    private readonly RagSettings _ragSettings;
    private readonly ILogger<RagasEvaluationService> _logger;

    public RagasEvaluationService(
        ISubjectRepository subjectRepository,
        IEvaluationQuestionRepository questionRepository,
        IEvaluationQuestionGoldChunkRepository goldChunkRepository,
        IDocumentChunkRepository documentChunkRepository,
        IRagasBenchmarkResultRepository resultRepository,
        IEmbeddingModelRegistry embeddingModelRegistry,
        IEmbeddingBackfillService backfillService,
        IVectorSearchService vectorSearchService,
        IRagasEvaluatorClient ragasEvaluatorClient,
        ILlmService llmService,
        PromptBuilder promptBuilder,
        ISystemSettingsService settingsService,
        IRagasEvaluationProgressReporter progressReporter,
        IBenchmarkMetricCalculator metricCalculator,
        IConfiguration configuration,
        ILogger<RagasEvaluationService> logger)
    {
        _subjectRepository = subjectRepository;
        _questionRepository = questionRepository;
        _goldChunkRepository = goldChunkRepository;
        _documentChunkRepository = documentChunkRepository;
        _resultRepository = resultRepository;
        _embeddingModelRegistry = embeddingModelRegistry;
        _backfillService = backfillService;
        _vectorSearchService = vectorSearchService;
        _ragasEvaluatorClient = ragasEvaluatorClient;
        _llmService = llmService;
        _promptBuilder = promptBuilder;
        _settingsService = settingsService;
        _progressReporter = progressReporter;
        _metricCalculator = metricCalculator;
        _ragSettings = RagSettings.FromConfiguration(configuration);
        _logger = logger;
    }

    public async Task<IReadOnlyList<SubjectEvaluationSummaryDto>> GetSubjectSummariesAsync(
        CancellationToken cancellationToken = default)
    {
        var subjects = await _subjectRepository.GetAllAsync(cancellationToken);
        var summaries = new List<SubjectEvaluationSummaryDto>();

        foreach (var subject in subjects)
        {
            var questionCount = await _questionRepository.CountBySubjectAsync(subject.Id, cancellationToken);
            var runCount = await _resultRepository.CountBySubjectAsync(subject.Id, cancellationToken);
            var latestRunResults = await _resultRepository.GetLatestRunBySubjectAsync(subject.Id, cancellationToken);
            var answerableResults = latestRunResults
                .Where(result => !result.ExpectedNoAnswer)
                .ToList();
            var latestRecallAt5 = answerableResults.Count == 0
                ? (decimal?)null
                : answerableResults.Average(result => result.RecallAt5 ?? 0);
            var latestRunDate = latestRunResults.Count == 0
                ? (DateTime?)null
                : latestRunResults.Max(result => result.CreatedAt);

            summaries.Add(new SubjectEvaluationSummaryDto(
                subject.Id,
                subject.SubjectCode,
                subject.SubjectName,
                questionCount,
                runCount,
                latestRecallAt5,
                latestRunDate));
        }

        return summaries;
    }

    public async Task<IReadOnlyList<EvaluationQuestionDto>> GetQuestionsAsync(
        int subjectId,
        CancellationToken cancellationToken = default)
    {
        var questions = await _questionRepository.GetBySubjectAsync(subjectId, cancellationToken);
        return questions.Select(question => new EvaluationQuestionDto(
            question.Id,
            question.SubjectId,
            question.Subject?.SubjectName ?? string.Empty,
            question.Question,
            question.GroundTruthAnswer,
            question.IsAnswerable,
            IsQuestionReady(question),
            question.GoldChunks.Count,
            question.CreatedByNavigation?.FullName,
            question.CreatedAt)).ToList();
    }

    public async Task<EvaluationQuestionSetupDto?> GetQuestionSetupAsync(
        int questionId,
        CancellationToken cancellationToken = default)
    {
        var question = await _questionRepository.GetByIdAsync(questionId, cancellationToken);
        if (question is null)
        {
            return null;
        }

        return new EvaluationQuestionSetupDto(
            question.Id,
            question.SubjectId,
            question.Subject?.SubjectName ?? string.Empty,
            question.Question,
            question.GroundTruthAnswer,
            question.IsAnswerable,
            IsQuestionReady(question),
            question.GoldChunks.Select(MapGoldChunk).ToList());
    }

    public async Task<IReadOnlyList<BenchmarkChunkCandidateDto>> SuggestGoldChunksAsync(
        int questionId,
        string? searchTerm = null,
        CancellationToken cancellationToken = default)
    {
        var question = await _questionRepository.GetByIdAsync(questionId, cancellationToken);
        if (question is null)
        {
            return [];
        }

        var selected = question.GoldChunks.ToDictionary(
            item => item.DocumentChunkId,
            item => item.RelevanceGrade);
        var chunks = await _documentChunkRepository.GetIndexedChunksBySubjectForBackfillAsync(
            question.SubjectId,
            cancellationToken);

        var candidates = chunks
            .Where(chunk =>
                selected.ContainsKey(chunk.Id)
                || string.IsNullOrWhiteSpace(searchTerm)
                || chunk.Content.Contains(searchTerm.Trim(), StringComparison.OrdinalIgnoreCase)
                || chunk.Document.Title.Contains(searchTerm.Trim(), StringComparison.OrdinalIgnoreCase)
                || chunk.Document.OriginalFileName.Contains(searchTerm.Trim(), StringComparison.OrdinalIgnoreCase))
            .Select(chunk => new
            {
                Chunk = chunk,
                Score = CalculateLexicalSuggestionScore(
                    question.Question,
                    question.GroundTruthAnswer,
                    chunk.Content),
                IsSelected = selected.ContainsKey(chunk.Id)
            })
            .OrderByDescending(item => item.IsSelected)
            .ThenByDescending(item => item.Score)
            .ThenBy(item => item.Chunk.Document.Title)
            .ThenBy(item => item.Chunk.ChunkIndex)
            .Take(20)
            .Select(item => new BenchmarkChunkCandidateDto(
                item.Chunk.Id,
                item.Chunk.DocumentId,
                item.Chunk.Document.Title,
                item.Chunk.Document.OriginalFileName,
                item.Chunk.ChunkIndex,
                item.Chunk.PageNumber,
                item.Chunk.SlideNumber,
                item.Chunk.Content,
                item.Score,
                item.IsSelected,
                selected.GetValueOrDefault(item.Chunk.Id)))
            .ToList();

        return candidates;
    }

    public async Task<OperationResult> SaveQuestionBenchmarkSetupAsync(
        SaveQuestionBenchmarkSetupRequest request,
        CancellationToken cancellationToken = default)
    {
        var question = await _questionRepository.GetByIdAsync(request.QuestionId, cancellationToken);
        if (question is null)
        {
            return new OperationResult(false, "Không tìm thấy câu hỏi đánh giá.");
        }

        var selections = request.GoldChunks
            .GroupBy(item => item.ChunkId)
            .Select(group => group.First())
            .ToList();

        if (selections.Any(item => item.RelevanceGrade is < 1 or > 2))
        {
            return new OperationResult(false, "Mức liên quan của gold chunk chỉ nhận giá trị 1 hoặc 2.");
        }

        if (!request.IsAnswerable && selections.Count > 0)
        {
            return new OperationResult(false, "Câu hỏi không có đáp án không được gắn gold chunk.");
        }

        if (request.IsAnswerable && !selections.Any(item => item.RelevanceGrade == 2))
        {
            return new OperationResult(false, "Câu hỏi có đáp án cần ít nhất một gold chunk chứa trực tiếp đáp án.");
        }

        var chunks = await _documentChunkRepository.GetIndexedChunksByIdsAsync(
            selections.Select(item => item.ChunkId),
            cancellationToken);
        if (chunks.Count != selections.Count
            || chunks.Any(chunk => chunk.Document.SubjectId != question.SubjectId))
        {
            return new OperationResult(false, "Gold chunk không hợp lệ hoặc không thuộc môn học này.");
        }

        question.IsAnswerable = request.IsAnswerable;
        var now = DateTime.UtcNow;
        var goldChunks = selections.Select(item => new EvaluationQuestionGoldChunk
        {
            EvaluationQuestionId = question.Id,
            DocumentChunkId = item.ChunkId,
            RelevanceGrade = item.RelevanceGrade,
            CreatedAt = now
        }).ToList();

        await _goldChunkRepository.SaveSetupAsync(question, goldChunks, cancellationToken);
        return new OperationResult(true, "Đã lưu cấu hình benchmark cho câu hỏi.");
    }

    public async Task<BenchmarkReadinessDto> GetBenchmarkReadinessAsync(
        int subjectId,
        CancellationToken cancellationToken = default)
    {
        var questions = await _questionRepository.GetBySubjectAsync(subjectId, cancellationToken);
        var errors = new List<string>();
        var readyCount = questions.Count(IsQuestionReady);
        var answerableCount = questions.Count(question => question.IsAnswerable);
        var unanswerableCount = questions.Count - answerableCount;

        if (questions.Count == 0)
        {
            errors.Add("Môn học chưa có câu hỏi benchmark.");
        }

        if (readyCount != questions.Count)
        {
            errors.Add($"Còn {questions.Count - readyCount} câu hỏi chưa cấu hình gold data.");
        }

        if (answerableCount == 0)
        {
            errors.Add("Dataset cần ít nhất một câu hỏi có đáp án.");
        }

        if (unanswerableCount == 0)
        {
            errors.Add("Dataset cần ít nhất một câu hỏi không có đáp án để tính No-answer F1.");
        }

        return new BenchmarkReadinessDto(
            errors.Count == 0,
            questions.Count,
            readyCount,
            answerableCount,
            unanswerableCount,
            errors);
    }

    public IReadOnlyList<BenchmarkChunkingStrategyDto> GetChunkingStrategies()
    {
        return
        [
            new BenchmarkChunkingStrategyDto(
                "default",
                "Default",
                "Top-K và số chunk ngữ cảnh theo cấu hình hệ thống.",
                true),
            new BenchmarkChunkingStrategyDto(
                "precision",
                "Precision",
                "Lấy ít chunk hơn để ưu tiên độ chính xác và giảm nhiễu.",
                false),
            new BenchmarkChunkingStrategyDto(
                "recall",
                "Recall",
                "Lấy nhiều chunk hơn để kiểm tra độ bao phủ ngữ cảnh.",
                false)
        ];
    }

    public async Task<CreateEvaluationQuestionResult> AddQuestionAsync(
        int subjectId,
        string question,
        string groundTruthAnswer,
        int createdBy,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var entity = await _questionRepository.AddAsync(new EvaluationQuestion
            {
                SubjectId = subjectId,
                Question = question.Trim(),
                GroundTruthAnswer = groundTruthAnswer.Trim(),
                IsAnswerable = true,
                CreatedBy = createdBy,
                CreatedAt = DateTime.UtcNow
            }, cancellationToken);

            return new CreateEvaluationQuestionResult(
                true,
                "Thêm câu hỏi thành công. Hãy xác nhận gold chunks để hoàn tất.",
                entity.Id);
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Unable to add evaluation question");
            return new CreateEvaluationQuestionResult(false, "Đã xảy ra lỗi hệ thống.");
        }
    }

    public async Task<OperationResult> UpdateQuestionAsync(int id, string question, string groundTruthAnswer, CancellationToken cancellationToken = default)
    {
        try
        {
            var entity = await _questionRepository.GetByIdAsync(id, cancellationToken);
            if (entity is null)
            {
                return new OperationResult(false, "Không tìm thấy câu hỏi.");
            }

            entity.Question = question.Trim();
            entity.GroundTruthAnswer = groundTruthAnswer.Trim();
            await _questionRepository.UpdateAsync(entity, cancellationToken);
            return new OperationResult(true, "Cập nhật câu hỏi thành công.");
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Unable to update evaluation question");
            return new OperationResult(false, "Đã xảy ra lỗi hệ thống.");
        }
    }

    public async Task<OperationResult> DeleteQuestionAsync(int id, CancellationToken cancellationToken = default)
    {
        try
        {
            var entity = await _questionRepository.GetByIdAsync(id, cancellationToken);
            if (entity is null)
            {
                return new OperationResult(false, "Không tìm thấy câu hỏi.");
            }

            await _questionRepository.DeleteAsync(entity, cancellationToken);
            return new OperationResult(true, "Xóa câu hỏi thành công.");
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Unable to delete evaluation question");
            return new OperationResult(false, "Đã xảy ra lỗi hệ thống.");
        }
    }

    public async Task<OperationResult> SeedQuestionsAsync(int subjectId, int createdBy, CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId, cancellationToken);
        if (subject is null)
        {
            return new OperationResult(false, "Không tìm thấy môn học.");
        }

        var existingQuestions = await _questionRepository.GetBySubjectAsync(subjectId, cancellationToken);
        if (existingQuestions.Count >= Phase4QuestionTarget)
        {
            return new OperationResult(false, $"Môn học này đã có đủ {Phase4QuestionTarget} câu hỏi benchmark.");
        }

        var seededAt = DateTime.UtcNow;
        var existingQuestionTexts = existingQuestions
            .Select(question => question.Question)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var phase4Questions = GeneratePhase4QuestionTemplates(subject)
            .Where(template => !existingQuestionTexts.Contains(template.Question))
            .Take(Phase4QuestionTarget - existingQuestions.Count)
            .Select((template, index) => new EvaluationQuestion
            {
                SubjectId = subjectId,
                Question = template.Question,
                GroundTruthAnswer = template.GroundTruthAnswer,
                IsAnswerable = true,
                CreatedBy = createdBy,
                CreatedAt = seededAt.AddTicks(index)
            })
            .ToList();

        if (phase4Questions.Count == 0)
        {
            return new OperationResult(false, "Không có câu hỏi mẫu mới để thêm.");
        }

        await _questionRepository.AddRangeAsync(phase4Questions, cancellationToken);
        return new OperationResult(true, $"Đã tạo thêm {phase4Questions.Count} câu hỏi. Tổng test set mục tiêu: {Phase4QuestionTarget} cau.");
    }


    public async Task<RagasRunSummaryDto?> RunEvaluationAsync(
        int subjectId,
        IReadOnlyList<string>? embeddingModels = null,
        IReadOnlyList<string>? chunkingStrategies = null,
        RagasEvaluationProgressContext? progressContext = null,
        CancellationToken cancellationToken = default)
    {
        var readiness = await GetBenchmarkReadinessAsync(subjectId, cancellationToken);
        if (!readiness.IsReady)
        {
            throw new InvalidOperationException(string.Join(" ", readiness.Errors));
        }

        var questions = await _questionRepository.GetBySubjectAsync(subjectId, cancellationToken);
        var subject = await _subjectRepository.GetByIdAsync(subjectId, cancellationToken);
        if (subject is null)
        {
            return null;
        }

        var settings = await _settingsService.GetSettingsAsync(cancellationToken);
        var modelKeys = ResolveModelKeys(embeddingModels);
        var strategies = ResolveChunkingStrategies(chunkingStrategies);
        var runId = progressContext is null
            ? $"ragas-{DateTime.UtcNow:yyyyMMddHHmmssfff}"
            : $"ragas-{progressContext.EvaluationId}";
        var runTime = DateTime.UtcNow;
        var results = new List<RagasBenchmarkResult>();
        var totalSteps = modelKeys.Count
            + (modelKeys.Count * strategies.Count * questions.Count * 2)
            + 1;
        var tracker = progressContext is null
            ? null
            : new RagasEvaluationProgressTracker(
                progressContext,
                subjectId,
                totalSteps,
                questions.Count,
                _progressReporter,
                _logger);

        try
        {
            if (tracker is not null)
            {
                await tracker.ReportAsync(
                    "Preparing",
                    "Đang chuẩn bị dữ liệu benchmark V2...",
                    cancellationToken: cancellationToken);
            }

            foreach (var modelKey in modelKeys)
            {
                if (tracker is not null)
                {
                    await tracker.ReportAsync(
                        "Backfilling",
                        $"Đang chuẩn bị embedding cho model {modelKey}...",
                        currentModel: modelKey,
                        cancellationToken: cancellationToken);
                }

                await _backfillService.BackfillSubjectAsync(subjectId, modelKey, cancellationToken);

                if (tracker is not null)
                {
                    await tracker.ReportAsync(
                        "Backfilling",
                        $"Đã chuẩn bị embedding cho model {modelKey}.",
                        advanceSteps: 1,
                        currentModel: modelKey,
                        cancellationToken: cancellationToken);
                }

                var embeddingService = _embeddingModelRegistry.GetRequired(modelKey);

                foreach (var strategy in strategies)
                {
                    var pendingResults = new List<RagasBenchmarkResult>();
                    var samples = new List<RagasEvaluationSample>();
                    var scoredResultIndexes = new List<int>();

                    for (var questionIndex = 0; questionIndex < questions.Count; questionIndex++)
                    {
                        var question = questions[questionIndex];
                        var currentQuestion = questionIndex + 1;

                        if (tracker is not null)
                        {
                            await tracker.ReportAsync(
                                "Generating",
                                $"Đang xử lý câu {currentQuestion}/{questions.Count} với {modelKey} · {strategy.Key}...",
                                currentModel: modelKey,
                                currentStrategy: strategy.Key,
                                currentQuestion: currentQuestion,
                                cancellationToken: cancellationToken);
                        }

                        var endToEndTimer = Stopwatch.StartNew();
                        var embeddingTimer = Stopwatch.StartNew();
                        var questionEmbedding = await embeddingService.GenerateEmbeddingAsync(
                            question.Question,
                            cancellationToken);
                        embeddingTimer.Stop();

                        var retrievalTimer = Stopwatch.StartNew();
                        var rankedChunks = await _vectorSearchService.SearchAsync(
                            subjectId,
                            embeddingService.ModelKey,
                            questionEmbedding,
                            10,
                            cancellationToken);
                        retrievalTimer.Stop();

                        var contextChunks = rankedChunks
                            .Take(strategy.TopK)
                            .Where(chunk => chunk.SimilarityScore >= _ragSettings.SimilarityThreshold)
                            .Take(strategy.MaxContextChunks)
                            .ToList();
                        var predictedNoAnswer = contextChunks.Count == 0;

                        var generationTimer = Stopwatch.StartNew();
                        var answer = predictedNoAnswer
                            ? NotFoundAnswer
                            : await GenerateBenchmarkAnswerAsync(
                                question.Question,
                                contextChunks,
                                cancellationToken);
                        generationTimer.Stop();
                        endToEndTimer.Stop();

                        var goldRelevance = question.GoldChunks.ToDictionary(
                            item => item.DocumentChunkId,
                            item => item.RelevanceGrade);
                        var retrievalScore = question.IsAnswerable
                            ? _metricCalculator.CalculateRetrieval(
                                rankedChunks.Select(chunk => chunk.ChunkId).ToList(),
                                goldRelevance)
                            : null;
                        var citationScore = question.IsAnswerable
                            ? _metricCalculator.CalculateCitation(
                                contextChunks.Select(chunk => chunk.ChunkId).ToList(),
                                goldRelevance.Keys.ToList())
                            : null;

                        var result = new RagasBenchmarkResult
                        {
                            EvaluationQuestionId = question.Id,
                            RunId = runId,
                            EmbeddingModel = embeddingService.ModelKey,
                            LlmModel = _llmService.ModelName,
                            VectorStore = rankedChunks.FirstOrDefault()?.RetrievalBackend ?? "Sql",
                            ChunkingStrategy = strategy.Key,
                            GeneratedAnswer = answer,
                            RetrievedContextsJson = JsonSerializer.Serialize(
                                contextChunks.Select(chunk => chunk.Content).ToList()),
                            RetrievedChunkIdsJson = JsonSerializer.Serialize(
                                rankedChunks.Select(chunk => chunk.ChunkId).ToList()),
                            CitationChunkIdsJson = JsonSerializer.Serialize(
                                contextChunks.Select(chunk => chunk.ChunkId).ToList()),
                            RecallAt5 = retrievalScore?.RecallAt5,
                            MrrAt10 = retrievalScore?.MrrAt10,
                            NdcgAt5 = retrievalScore?.NdcgAt5,
                            CitationPrecision = citationScore?.Precision,
                            CitationRecall = citationScore?.Recall,
                            CitationF1 = citationScore?.F1,
                            ExpectedNoAnswer = !question.IsAnswerable,
                            PredictedNoAnswer = predictedNoAnswer,
                            EmbeddingLatencyMs = embeddingTimer.ElapsedMilliseconds,
                            RetrievalLatencyMs = retrievalTimer.ElapsedMilliseconds,
                            GenerationLatencyMs = generationTimer.ElapsedMilliseconds,
                            EndToEndLatencyMs = endToEndTimer.ElapsedMilliseconds,
                            CreatedAt = runTime
                        };

                        pendingResults.Add(result);
                        if (question.IsAnswerable)
                        {
                            scoredResultIndexes.Add(pendingResults.Count - 1);
                            samples.Add(new RagasEvaluationSample(
                                question.Question,
                                question.GroundTruthAnswer,
                                answer,
                                contextChunks.Select(chunk => chunk.Content).ToList()));
                        }

                        if (tracker is not null)
                        {
                            await tracker.ReportAsync(
                                "Generating",
                                $"Đã xử lý câu {currentQuestion}/{questions.Count} với {modelKey} · {strategy.Key}.",
                                advanceSteps: 1,
                                currentModel: modelKey,
                                currentStrategy: strategy.Key,
                                currentQuestion: currentQuestion,
                                enableEstimate: true,
                                cancellationToken: cancellationToken);
                        }
                    }

                    var scoredQuestions = 0;
                    if (tracker is not null)
                    {
                        await tracker.ReportAsync(
                            "Scoring",
                            $"Đang chấm {samples.Count} câu có đáp án với {modelKey} · {strategy.Key}...",
                            currentModel: modelKey,
                            currentStrategy: strategy.Key,
                            cancellationToken: cancellationToken);
                    }

                    var scores = await EvaluateWithRagasOrFallbackAsync(
                        samples,
                        settings.EvaluationSystemPrompt,
                        async completedCount =>
                        {
                            scoredQuestions = Math.Min(samples.Count, scoredQuestions + completedCount);
                            if (tracker is not null)
                            {
                                await tracker.ReportAsync(
                                    "Scoring",
                                    $"Đã chấm {scoredQuestions}/{samples.Count} câu với {modelKey} · {strategy.Key}.",
                                    advanceSteps: completedCount,
                                    currentModel: modelKey,
                                    currentStrategy: strategy.Key,
                                    currentQuestion: scoredQuestions,
                                    enableEstimate: true,
                                    cancellationToken: cancellationToken);
                            }
                        },
                        cancellationToken);

                    for (var scoreIndex = 0; scoreIndex < scores.Count; scoreIndex++)
                    {
                        var resultIndex = scoredResultIndexes[scoreIndex];
                        pendingResults[resultIndex].AnswerCorrectness = scores[scoreIndex].AnswerCorrectness;
                        pendingResults[resultIndex].Faithfulness = scores[scoreIndex].Faithfulness;
                    }

                    var unanswerableCount = pendingResults.Count - scoredResultIndexes.Count;
                    if (tracker is not null && unanswerableCount > 0)
                    {
                        await tracker.ReportAsync(
                            "Scoring",
                            $"Đã kiểm tra {unanswerableCount} câu không có đáp án.",
                            advanceSteps: unanswerableCount,
                            currentModel: modelKey,
                            currentStrategy: strategy.Key,
                            enableEstimate: true,
                            cancellationToken: cancellationToken);
                    }

                    results.AddRange(pendingResults);
                }
            }

            if (tracker is not null)
            {
                await tracker.ReportAsync(
                    "Saving",
                    "Đang lưu kết quả benchmark V2...",
                    cancellationToken: cancellationToken);
            }

            await _resultRepository.AddRangeAsync(results, cancellationToken);

            if (tracker is not null)
            {
                await tracker.ReportAsync(
                    "Completed",
                    "Đánh giá embedding đã hoàn tất.",
                    advanceSteps: 1,
                    isCompleted: true,
                    cancellationToken: cancellationToken);
            }

            return CreateSummary(subjectId, subject.SubjectName, runTime, results, questions);
        }
        catch (Exception)
        {
            if (tracker is not null)
            {
                await tracker.ReportAsync(
                    "Failed",
                    "Đánh giá embedding không thể hoàn tất. Vui lòng kiểm tra log hệ thống.",
                    isFailed: true,
                    cancellationToken: CancellationToken.None);
            }

            throw;
        }
    }

    public async Task<RagasRunSummaryDto?> GetLatestRunAsync(
        int subjectId,
        CancellationToken cancellationToken = default)
    {
        var latestRunResults = await _resultRepository.GetLatestRunBySubjectAsync(
            subjectId,
            cancellationToken);
        return await CreateRunSummaryAsync(subjectId, latestRunResults, cancellationToken);
    }

    public async Task<RagasRunSummaryDto?> GetRunAsync(
        int subjectId,
        string runId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(runId))
        {
            return null;
        }

        var runResults = await _resultRepository.GetRunBySubjectAsync(
            subjectId,
            runId.Trim(),
            cancellationToken);
        return await CreateRunSummaryAsync(subjectId, runResults, cancellationToken);
    }

    public async Task<RagasRunHistoryDto?> GetRunHistoryAsync(
        int subjectId,
        int pageNumber,
        int pageSize,
        CancellationToken cancellationToken = default)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId, cancellationToken);
        if (subject is null)
        {
            return null;
        }

        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var page = await _resultRepository.GetRunHistoryBySubjectAsync(
            subjectId,
            pageNumber,
            pageSize,
            cancellationToken);

        return new RagasRunHistoryDto(
            subjectId,
            subject.SubjectName,
            pageNumber,
            pageSize,
            page.TotalCount,
            page.Items.Select(item => new RagasRunHistoryItemDto(
                item.RunId,
                item.RunDate,
                item.EmbeddingModels,
                item.ChunkingStrategies,
                item.QuestionCount,
                item.AvgRecallAt5)).ToList());
    }

    private async Task<RagasRunSummaryDto?> CreateRunSummaryAsync(
        int subjectId,
        IReadOnlyList<RagasBenchmarkResult> runResults,
        CancellationToken cancellationToken)
    {
        if (runResults.Count == 0)
        {
            return null;
        }

        var subject = await _subjectRepository.GetByIdAsync(subjectId, cancellationToken);
        var questions = await _questionRepository.GetBySubjectAsync(subjectId, cancellationToken);
        return CreateSummary(
            subjectId,
            subject?.SubjectName ?? string.Empty,
            runResults.Max(result => result.CreatedAt),
            runResults,
            questions,
            await GetWeeklyTokenUsageAsync(subjectId, cancellationToken));
    }
    private IReadOnlyList<string> ResolveModelKeys(IReadOnlyList<string>? requestedModels)
    {
        var available = _embeddingModelRegistry.GetAvailableModels(benchmarkOnly: true);
        var requested = requestedModels?
            .Where(model => !string.IsNullOrWhiteSpace(model))
            .Select(model => model.Trim())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var selected = available
            .Where(model => requested is null || requested.Contains(model.Key))
            .Select(model => model.Key)
            .ToList();

        return selected.Count > 0
            ? selected
            : [_embeddingModelRegistry.GetDefault().ModelKey];
    }

    private IReadOnlyList<BenchmarkChunkingStrategy> ResolveChunkingStrategies(IReadOnlyList<string>? requestedStrategies)
    {
        var allStrategies = GetBenchmarkChunkingStrategies();
        var requested = requestedStrategies?
            .Where(strategy => !string.IsNullOrWhiteSpace(strategy))
            .Select(strategy => strategy.Trim())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var selected = allStrategies
            .Where(strategy => requested is null || requested.Contains(strategy.Key))
            .ToList();

        return selected.Count > 0
            ? selected
            : [allStrategies.First(strategy => string.Equals(strategy.Key, "default", StringComparison.OrdinalIgnoreCase))];
    }

    private static IReadOnlyList<BenchmarkChunkingStrategy> GetBenchmarkChunkingStrategies()
    {
        return
        [
            new BenchmarkChunkingStrategy(
                "default",
                "Default",
                "Top-K và số chunk ngữ cảnh theo cấu hình hệ thống.",
                TopK: 5,
                MaxContextChunks: 5),
            new BenchmarkChunkingStrategy(
                "precision",
                "Precision",
                "Lấy ít chunk hơn để ưu tiên độ chính xác và giảm nhiễu.",
                TopK: 3,
                MaxContextChunks: 3),
            new BenchmarkChunkingStrategy(
                "recall",
                "Recall",
                "Lấy nhiều chunk hơn để kiểm tra độ bao phủ ngữ cảnh.",
                TopK: 8,
                MaxContextChunks: 8)
        ];
    }

    private async Task<IReadOnlyList<RagasEvaluationScore>> EvaluateWithRagasOrFallbackAsync(
        IReadOnlyList<RagasEvaluationSample> samples,
        string systemPrompt,
        Func<int, Task>? reportScoresCompleted,
        CancellationToken cancellationToken)
    {
        if (samples.Count == 0)
        {
            return [];
        }

        try
        {
            var ragasScores = await _ragasEvaluatorClient.EvaluateAsync(samples, cancellationToken);
            if (ragasScores.Count == samples.Count)
            {
                if (reportScoresCompleted is not null)
                {
                    await reportScoresCompleted(samples.Count);
                }

                return ragasScores;
            }
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "RAGAS service failed. Falling back to in-process LLM judge.");
        }

        var fallbackScores = new List<RagasEvaluationScore>();
        foreach (var sample in samples)
        {
            fallbackScores.Add(await EvaluateWithLlmJudgeAsync(sample, systemPrompt, cancellationToken));
            if (reportScoresCompleted is not null)
            {
                await reportScoresCompleted(1);
            }
        }

        return fallbackScores;
    }

    private async Task<RagasEvaluationScore> EvaluateWithLlmJudgeAsync(
        RagasEvaluationSample sample,
        string systemPrompt,
        CancellationToken cancellationToken)
    {
        var judgeInstruction = string.IsNullOrWhiteSpace(systemPrompt)
            ? "Bạn là hệ thống chấm chất lượng RAG."
            : systemPrompt;
        var context = string.Join(Environment.NewLine, sample.RetrievedContexts);
        var prompt = $$"""
            {{judgeInstruction}}

            Chấm theo thang 0.0 đến 1.0:
            - answer_correctness: câu trả lời sinh ra đúng và đầy đủ so với câu trả lời chuẩn.
            - faithfulness: các nhận định trong câu trả lời được ngữ cảnh hỗ trợ, không bịa thêm.

            Câu hỏi: {{sample.Question}}
            Câu trả lời chuẩn: {{sample.GroundTruthAnswer}}
            Ngữ cảnh: {{context}}
            Câu trả lời sinh ra: {{sample.GeneratedAnswer}}

            Chỉ trả về JSON:
            {"answer_correctness":0.0,"faithfulness":0.0}
            """;

        try
        {
            var llmResponse = await _llmService.GenerateAnswerAsync(prompt, cancellationToken);
            var jsonStartIndex = llmResponse.Text.IndexOf('{');
            var jsonEndIndex = llmResponse.Text.LastIndexOf('}');
            if (jsonStartIndex >= 0 && jsonEndIndex >= jsonStartIndex)
            {
                var json = llmResponse.Text.Substring(jsonStartIndex, jsonEndIndex - jsonStartIndex + 1);
                var score = JsonSerializer.Deserialize<LlmScore>(json);
                if (score is not null)
                {
                    return new RagasEvaluationScore(
                        Math.Clamp(score.AnswerCorrectness, 0, 1),
                        Math.Clamp(score.Faithfulness, 0, 1));
                }
            }
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "LLM judge fallback failed");
        }

        return CalculateHeuristicScore(sample);
    }

    private async Task<string> GenerateBenchmarkAnswerAsync(
        string question,
        IReadOnlyList<RetrievedChunkDto> contextChunks,
        CancellationToken cancellationToken)
    {
        try
        {
            var response = await _llmService.GenerateAnswerAsync(
                _promptBuilder.Build(question, contextChunks),
                cancellationToken);
            return response.Text;
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "LLM generation failed during benchmark. Using retrieved-context fallback answer.");
            return CreateFallbackAnswer(contextChunks);
        }
    }

    private static string CreateFallbackAnswer(IReadOnlyList<RetrievedChunkDto> contextChunks)
    {
        if (contextChunks.Count == 0)
        {
            return "Không tìm thấy thông tin liên quan trong tài liệu đã tải lên.";
        }

        var context = NormalizeWhitespace(contextChunks[0].Content);
        return context.Length <= 700 ? context : $"{context[..700]}...";
    }

    private static RagasEvaluationScore CalculateHeuristicScore(RagasEvaluationSample sample)
    {
        var context = string.Join(' ', sample.RetrievedContexts);
        return new RagasEvaluationScore(
            TokenOverlap(sample.GeneratedAnswer, sample.GroundTruthAnswer),
            TokenOverlap(sample.GeneratedAnswer, context));
    }

    private static decimal TokenOverlap(string left, string right)
    {
        var leftTokens = Tokenize(left);
        var rightTokens = Tokenize(right);

        if (leftTokens.Count == 0 || rightTokens.Count == 0)
        {
            return 0;
        }

        var overlap = leftTokens.Count(token => rightTokens.Contains(token));
        return Math.Round((decimal)overlap / leftTokens.Count, 4);
    }

    private static HashSet<string> Tokenize(string value)
    {
        return Regex.Matches(
                value.ToLowerInvariant(),
                @"[\p{L}\p{N}]{3,}",
                RegexOptions.CultureInvariant)
            .Select(match => match.Value)
            .Where(token => !StopWords.Contains(token))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
    }

    private static string NormalizeWhitespace(string value)
    {
        return Regex.Replace(value, @"\s+", " ").Trim();
    }

    private static readonly HashSet<string> StopWords = new(StringComparer.OrdinalIgnoreCase)
    {
        "cac",
        "cho",
        "cua",
        "duoc",
        "la",
        "mot",
        "nhung",
        "the",
        "thi",
        "trong",
        "va",
        "voi"
    };

    private static bool IsQuestionReady(EvaluationQuestion question)
    {
        return question.IsAnswerable
            ? question.GoldChunks.Any(item => item.RelevanceGrade == 2)
            : question.GoldChunks.Count == 0;
    }

    private static EvaluationQuestionGoldChunkDto MapGoldChunk(
        EvaluationQuestionGoldChunk item)
    {
        var chunk = item.DocumentChunk;
        return new EvaluationQuestionGoldChunkDto(
            chunk.Id,
            chunk.DocumentId,
            chunk.Document.Title,
            chunk.Document.OriginalFileName,
            chunk.ChunkIndex,
            chunk.PageNumber,
            chunk.SlideNumber,
            chunk.Content,
            item.RelevanceGrade);
    }

    private static decimal CalculateLexicalSuggestionScore(
        string question,
        string groundTruthAnswer,
        string chunkContent)
    {
        var queryTokens = Tokenize($"{question} {groundTruthAnswer}");
        var chunkTokens = Tokenize(chunkContent);
        if (queryTokens.Count == 0 || chunkTokens.Count == 0)
        {
            return 0;
        }

        var overlap = queryTokens.Count(chunkTokens.Contains);
        return Math.Round(overlap / (decimal)queryTokens.Count, 4);
    }

    private RagasRunSummaryDto CreateSummary(
        int subjectId,
        string subjectName,
        DateTime runDate,
        IReadOnlyList<RagasBenchmarkResult> results,
        IReadOnlyList<EvaluationQuestion> questions,
        IReadOnlyList<RagasTokenUsageSummaryDto>? weeklyTokenUsage = null)
    {
        var questionById = questions.ToDictionary(question => question.Id);
        var modelSummaries = results
            .GroupBy(result => new { result.EmbeddingModel, result.ChunkingStrategy })
            .Select(group =>
            {
                var rows = group.ToList();
                var answerableRows = rows.Where(result => !result.ExpectedNoAnswer).ToList();
                var noAnswerF1 = _metricCalculator.CalculateNoAnswerF1(
                    rows.Select(result => new NoAnswerPrediction(
                        result.ExpectedNoAnswer,
                        result.PredictedNoAnswer)));

                return new RagasModelSummaryDto(
                    group.Key.EmbeddingModel,
                    rows.FirstOrDefault()?.LlmModel,
                    rows.FirstOrDefault()?.VectorStore,
                    group.Key.ChunkingStrategy,
                    rows.Count,
                    AverageMetric(answerableRows.Select(result => result.RecallAt5)),
                    AverageMetric(answerableRows.Select(result => result.MrrAt10)),
                    AverageMetric(answerableRows.Select(result => result.NdcgAt5)),
                    AverageMetric(answerableRows.Select(result => result.AnswerCorrectness)),
                    AverageMetric(answerableRows.Select(result => result.Faithfulness)),
                    AverageMetric(answerableRows.Select(result => result.CitationF1)),
                    noAnswerF1,
                    _metricCalculator.CalculatePercentile(rows.Select(result => result.EmbeddingLatencyMs), 0.50m),
                    _metricCalculator.CalculatePercentile(rows.Select(result => result.EmbeddingLatencyMs), 0.95m),
                    _metricCalculator.CalculatePercentile(rows.Select(result => result.RetrievalLatencyMs), 0.50m),
                    _metricCalculator.CalculatePercentile(rows.Select(result => result.RetrievalLatencyMs), 0.95m),
                    _metricCalculator.CalculatePercentile(rows.Select(result => result.EndToEndLatencyMs), 0.50m),
                    _metricCalculator.CalculatePercentile(rows.Select(result => result.EndToEndLatencyMs), 0.95m));
            })
            .OrderByDescending(summary => summary.AvgRecallAt5)
            .ThenByDescending(summary => summary.AvgMrrAt10)
            .ThenByDescending(summary => summary.AvgFaithfulness)
            .ThenByDescending(summary => summary.AvgCitationF1)
            .ThenBy(summary => summary.EndToEndLatencyP95Ms)
            .ToList();

        var resultDtos = results.Select(result =>
        {
            var question = questionById.GetValueOrDefault(result.EvaluationQuestionId);
            return new RagasBenchmarkResultDto(
                result.Id,
                result.EvaluationQuestionId,
                result.RunId,
                question?.Question ?? string.Empty,
                question?.GroundTruthAnswer,
                !result.ExpectedNoAnswer,
                result.EmbeddingModel,
                result.LlmModel,
                result.VectorStore,
                result.ChunkingStrategy,
                result.GeneratedAnswer,
                result.RetrievedContextsJson,
                DeserializeChunkIds(result.RetrievedChunkIdsJson),
                DeserializeChunkIds(result.CitationChunkIdsJson),
                result.RecallAt5,
                result.MrrAt10,
                result.NdcgAt5,
                result.AnswerCorrectness,
                result.Faithfulness,
                result.CitationPrecision,
                result.CitationRecall,
                result.CitationF1,
                result.ExpectedNoAnswer,
                result.PredictedNoAnswer,
                result.EmbeddingLatencyMs,
                result.RetrievalLatencyMs,
                result.GenerationLatencyMs,
                result.EndToEndLatencyMs,
                result.CreatedAt);
        }).ToList();

        var topSummary = modelSummaries.FirstOrDefault();
        var noAnswerScores = modelSummaries
            .Where(summary => summary.NoAnswerF1.HasValue)
            .Select(summary => summary.NoAnswerF1!.Value)
            .ToList();

        return new RagasRunSummaryDto(
            subjectId,
            subjectName,
            results.FirstOrDefault()?.RunId ?? string.Empty,
            topSummary?.EmbeddingModel ?? string.Empty,
            topSummary?.LlmModel,
            topSummary?.ChunkingStrategy ?? "default",
            results.Select(result => result.EvaluationQuestionId).Distinct().Count(),
            AverageMetric(modelSummaries.Select(summary => (decimal?)summary.AvgRecallAt5)),
            AverageMetric(modelSummaries.Select(summary => (decimal?)summary.AvgMrrAt10)),
            AverageMetric(modelSummaries.Select(summary => (decimal?)summary.AvgNdcgAt5)),
            AverageMetric(modelSummaries.Select(summary => (decimal?)summary.AvgAnswerCorrectness)),
            AverageMetric(modelSummaries.Select(summary => (decimal?)summary.AvgFaithfulness)),
            AverageMetric(modelSummaries.Select(summary => (decimal?)summary.AvgCitationF1)),
            noAnswerScores.Count == 0 ? null : noAnswerScores.Average(),
            _metricCalculator.CalculatePercentile(results.Select(result => result.EndToEndLatencyMs), 0.50m),
            _metricCalculator.CalculatePercentile(results.Select(result => result.EndToEndLatencyMs), 0.95m),
            runDate,
            modelSummaries,
            weeklyTokenUsage ?? [],
            resultDtos);
    }

    private static decimal AverageMetric(IEnumerable<decimal?> values)
    {
        var available = values
            .Where(value => value.HasValue)
            .Select(value => value!.Value)
            .ToList();
        return available.Count == 0 ? 0 : available.Average();
    }

    private static IReadOnlyList<int> DeserializeChunkIds(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            return [];
        }

        try
        {
            return JsonSerializer.Deserialize<List<int>>(json) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    private async Task<IReadOnlyList<RagasTokenUsageSummaryDto>> GetWeeklyTokenUsageAsync(
        int subjectId,
        CancellationToken cancellationToken)
    {
        var toUtc = DateTime.UtcNow;
        var fromUtc = toUtc.AddDays(-7);
        var weeklyResults = await _resultRepository.GetBySubjectSinceAsync(
            subjectId,
            fromUtc,
            cancellationToken);

        return weeklyResults
            .GroupBy(result => result.EmbeddingModel)
            .Select(group =>
            {
                var rows = group.ToList();
                var estimatedEmbeddingTokens = rows.Sum(result =>
                    EstimateTokens(result.EvaluationQuestion?.Question)
                    + EstimateTokensFromContexts(result.RetrievedContextsJson));
                var estimatedPromptTokens = rows.Sum(result =>
                    EstimateTokens(result.EvaluationQuestion?.Question)
                    + EstimateTokensFromContexts(result.RetrievedContextsJson));
                var estimatedCompletionTokens = rows.Sum(result => EstimateTokens(result.GeneratedAnswer));

                return new RagasTokenUsageSummaryDto(
                    group.Key,
                    rows.FirstOrDefault()?.LlmModel,
                    rows.Select(result => string.IsNullOrWhiteSpace(result.RunId)
                            ? result.CreatedAt.ToString("O")
                            : result.RunId)
                        .Distinct(StringComparer.OrdinalIgnoreCase)
                        .Count(),
                    rows.Count,
                    estimatedEmbeddingTokens,
                    estimatedPromptTokens,
                    estimatedCompletionTokens,
                    estimatedEmbeddingTokens + estimatedPromptTokens + estimatedCompletionTokens,
                    AverageMetric(rows.Where(result => !result.ExpectedNoAnswer).Select(result => result.RecallAt5)),
                    fromUtc,
                    toUtc);
            })
            .OrderByDescending(summary => summary.AvgRecallAt5)
            .ToList();
    }

    private static int EstimateTokensFromContexts(string? retrievedContextsJson)
    {
        if (string.IsNullOrWhiteSpace(retrievedContextsJson))
        {
            return 0;
        }

        try
        {
            var contexts = JsonSerializer.Deserialize<List<string>>(retrievedContextsJson) ?? [];
            return contexts.Sum(EstimateTokens);
        }
        catch (JsonException)
        {
            return EstimateTokens(retrievedContextsJson);
        }
    }

    private static int EstimateTokens(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return 0;
        }

        return Math.Max(1, (int)Math.Ceiling(text.Length / 4.0));
    }

    private static IReadOnlyList<Phase4QuestionTemplate> GeneratePhase4QuestionTemplates(Subject subject)
    {
        var subjectName = string.IsNullOrWhiteSpace(subject.SubjectName) ? "môn học" : subject.SubjectName;
        var subjectCode = string.IsNullOrWhiteSpace(subject.SubjectCode) ? "môn học này" : subject.SubjectCode;

        return
        [
            Q($"Tong quan cua {subjectName} la gi?", $"Cau tra loi can tom tat dung noi dung tong quan cua {subjectName} dua tren tai lieu da index."),
            Q($"Muc tieu hoc tap chinh cua {subjectCode} la gi?", $"Cau tra loi can neu cac muc tieu hoc tap cua {subjectCode} duoc trinh bay trong tai lieu."),
            Q($"Nhung khai niem nen tang nao xuat hien trong {subjectName}?", "Cau tra loi can liet ke cac khai niem nen tang co trong tai lieu va giai thich ngan gon."),
            Q($"Tai lieu mo ta quy trinh hoac cac buoc thuc hien nao quan trong?", "Cau tra loi can trich ra dung quy trinh/cac buoc neu co trong ngu canh tai lieu."),
            Q($"Dinh nghia quan trong nhat trong phan tai lieu da hoc la gi?", "Cau tra loi can dua ra dinh nghia nam trong tai lieu va khong tu bo sung ngoai ngu canh."),
            Q($"Vi du minh hoa nao duoc tai lieu su dung de giai thich bai hoc?", "Cau tra loi can neu vi du co trong tai lieu, kem noi dung lien quan neu truy xuat duoc."),
            Q($"Cac thanh phan chinh cua chu de trong {subjectName} gom nhung gi?", "Cau tra loi can liet ke cac thanh phan/chuc nang/yeu to duoc tai lieu neu ra."),
            Q($"Tai lieu phan biet nhung khai niem nao voi nhau?", "Cau tra loi can neu diem giong va khac nhau neu tai lieu co noi dung so sanh."),
            Q($"Noi dung nao trong tai lieu la dieu kien tien quyet de hieu bai?", "Cau tra loi can xac dinh kien thuc nen tang hoac dieu kien tien quyet co trong tai lieu."),
            Q($"Tai lieu dua ra cong thuc, mo hinh hoac cau truc nao dang chu y?", "Cau tra loi can trinh bay cong thuc/mo hinh/cau truc neu duoc tai lieu cung cap."),
            Q($"Y nghia thuc tien cua chu de nay la gi?", "Cau tra loi can dua tren ung dung, loi ich, hoac y nghia duoc neu trong tai lieu."),
            Q($"Cac loi thuong gap hoac han che nao duoc tai lieu de cap?", "Cau tra loi can neu loi, han che, rui ro hoac luu y co trong tai lieu."),
            Q($"Tai lieu co neu tieu chi danh gia nao khong?", "Cau tra loi can neu tieu chi, dieu kien, muc do, hoac cach danh gia neu co trong tai lieu."),
            Q($"Cac thuat ngu tieng Anh quan trong trong {subjectCode} la gi?", "Cau tra loi can liet ke thuat ngu va giai thich theo tai lieu neu co."),
            Q($"Bai hoc nay co lien he voi chu de nao truoc do?", "Cau tra loi can neu moi lien he voi kien thuc truoc/chu de lien quan neu tai lieu de cap."),
            Q($"Phan nao trong tai lieu giai thich ve nguyen ly hoat dong?", "Cau tra loi can tom tat nguyen ly hoat dong dua tren ngu canh truy xuat."),
            Q($"Tai lieu neu uu diem nao cua phuong phap hoac cong nghe dang hoc?", "Cau tra loi can dua ra cac uu diem duoc tai lieu trinh bay."),
            Q($"Tai lieu neu nhuoc diem nao cua phuong phap hoac cong nghe dang hoc?", "Cau tra loi can dua ra cac nhuoc diem/han che duoc tai lieu trinh bay."),
            Q($"Cac buoc ap dung kien thuc trong bai vao bai tap la gi?", "Cau tra loi can neu trinh tu ap dung neu tai lieu co huong dan."),
            Q($"Dau hieu nao cho thay mot cau tra loi dung voi noi dung tai lieu?", "Cau tra loi can dua ra cac dau hieu/diem chinh co trong tai lieu."),
            Q($"Tai lieu co neu truong hop su dung nao cho chu de nay?", "Cau tra loi can neu use case/boi canh ap dung neu co."),
            Q($"Cac yeu cau dau vao va dau ra cua quy trinh trong tai lieu la gi?", "Cau tra loi can neu input/output hoac dieu kien bat dau/ket qua neu tai lieu de cap."),
            Q($"Khac biet giua ly thuyet va vi du trong tai lieu la gi?", "Cau tra loi can so sanh ly thuyet voi vi du dua tren noi dung tai lieu."),
            Q($"Tai lieu co dua ra so do, bang bieu hoac hinh minh hoa nao quan trong?", "Cau tra loi can mo ta dung noi dung cua so do/bang/hinh neu duoc trich xuat."),
            Q($"Sinh vien can ghi nho nhung diem chinh nao sau bai hoc?", "Cau tra loi can tong hop cac y chinh co trong tai lieu."),
            Q($"Cau hoi nao trong tai lieu co the dung de on tap chu de nay?", "Cau tra loi can dua ra cac diem on tap dua tren noi dung tai lieu."),
            Q($"Tai lieu co nhac den quy tac, quy uoc hoac nguyen tac nao khong?", "Cau tra loi can neu quy tac/quy uoc/nguyen tac neu co trong tai lieu."),
            Q($"Khi nao nen ap dung phuong phap duoc trinh bay trong tai lieu?", "Cau tra loi can dua tren dieu kien ap dung duoc tai lieu neu ra."),
            Q($"Khi nao khong nen ap dung phuong phap duoc trinh bay trong tai lieu?", "Cau tra loi can dua tren ngoai le/han che neu tai lieu co de cap."),
            Q($"Tai lieu co dua ra phan loai nao cho chu de nay?", "Cau tra loi can liet ke cac loai/nhom va mo ta ngan gon neu tai lieu co."),
            Q($"Moi quan he giua cac thanh phan trong chu de la gi?", "Cau tra loi can mo ta quan he/phu thuoc/luong thong tin giua cac thanh phan neu co."),
            Q($"Noi dung nao trong tai lieu co the gay nham lan cho sinh vien?", "Cau tra loi can neu diem de nham lan va cach tai lieu phan biet neu co."),
            Q($"Tai lieu co neu muc tieu, pham vi hoac gioi han cua chu de khong?", "Cau tra loi can neu muc tieu, pham vi, gioi han theo tai lieu."),
            Q($"Cac tu khoa quan trong nhat de truy van tai lieu mon {subjectCode} la gi?", "Cau tra loi can dua ra tu khoa noi bat duoc suy ra tu noi dung tai lieu."),
            Q($"Tai lieu co neu cau truc bai hoc hoac muc luc lien quan khong?", "Cau tra loi can neu cau truc/muc luc/phan chia noi dung neu co."),
            Q($"Noi dung nao trong tai lieu lien quan truc tiep den bai tap thuc hanh?", "Cau tra loi can xac dinh phan ly thuyet/huong dan co the dung cho bai tap."),
            Q($"Tai lieu co de cap den cong cu, ky thuat hoac framework nao?", "Cau tra loi can liet ke cong cu/ky thuat/framework va vai tro cua chung neu co."),
            Q($"Cac gia dinh hoac dieu kien ban dau trong tai lieu la gi?", "Cau tra loi can neu assumption/dieu kien ban dau duoc tai lieu dua ra."),
            Q($"Tai lieu co neu cach kiem tra ket qua hoac validation nao khong?", "Cau tra loi can neu cach kiem tra/doi chieu ket qua neu tai lieu co."),
            Q($"Tai lieu co dua ra vi du phan tich tung buoc khong?", "Cau tra loi can tom tat vi du tung buoc neu ngu canh tai lieu co."),
            Q($"Chu de nay co lien quan den bao mat, hieu nang hoac do tin cay khong?", "Cau tra loi can chi tra loi neu tai lieu co noi dung ve bao mat/hieu nang/do tin cay."),
            Q($"Nhung noi dung nao nen duoc trich dan khi tra loi cau hoi ve chu de nay?", "Cau tra loi can neu cac doan/chunk co lien quan va ly do chung ho tro cau tra loi."),
            Q($"Tai lieu co neu cac muc do, giai doan hoac cap bac nao khong?", "Cau tra loi can liet ke cac muc do/giai doan/cap bac neu co."),
            Q($"Cac thuat toan, quy trinh hoac workflow nao xuat hien trong tai lieu?", "Cau tra loi can neu ten va mo ta ngan gon cac thuat toan/quy trinh/workflow neu co."),
            Q($"Noi dung nao trong tai lieu giai thich nguyen nhan va ket qua?", "Cau tra loi can neu moi quan he nhan qua neu tai lieu trinh bay."),
            Q($"Tai lieu co so sanh cac lua chon hoac cach tiep can khac nhau khong?", "Cau tra loi can tom tat bang/phan so sanh neu tai lieu co."),
            Q($"Sinh vien nen tra loi ngan gon the nao neu duoc hoi ve chu de chinh?", "Cau tra loi can tao cau tra loi ngan gon nhung dung theo tai lieu."),
            Q($"Noi dung nao trong tai lieu can duoc hoc thuoc hoac nam chac?", "Cau tra loi can neu cac dinh nghia, quy tac, cong thuc, hoac diem chinh can nam."),
            Q($"Tai lieu co noi gi ve ung dung cua kien thuc trong du an hoac thuc te?", "Cau tra loi can dua tren phan ung dung/du an/thuc te duoc tai lieu neu."),
            Q($"Neu khong tim thay thong tin trong tai lieu, cau tra loi dung nen la gi?", "Cau tra loi dung can noi ro khong tim thay thong tin trong tai lieu da tai len va khong bia noi dung.")
        ];

        static Phase4QuestionTemplate Q(string question, string answer) => new(question, answer);
    }

    private sealed record Phase4QuestionTemplate(string Question, string GroundTruthAnswer);

    private sealed record BenchmarkChunkingStrategy(
        string Key,
        string DisplayName,
        string Description,
        int TopK,
        int MaxContextChunks);

    private sealed class LlmScore
    {
        [JsonPropertyName("answer_correctness")]
        public decimal AnswerCorrectness { get; set; } = 0.5m;

        [JsonPropertyName("faithfulness")]
        public decimal Faithfulness { get; set; } = 0.5m;
    }
}
