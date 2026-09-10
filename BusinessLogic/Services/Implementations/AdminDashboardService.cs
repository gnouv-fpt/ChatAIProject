using BusinessLogic.Services.Interfaces;
using BusinessLogic.DTOs.Responses;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class AdminDashboardService : IAdminDashboardService
{
    private readonly IUserRepository _userRepository;
    private readonly ISubjectRepository _subjectRepository;
    private readonly IDocumentRepository _documentRepository;
    private readonly IChatRepository _chatRepository;
    private readonly IEvaluationQuestionRepository _evaluationQuestionRepository;
    private readonly IRagasBenchmarkResultRepository _ragasBenchmarkResultRepository;
    private readonly ILogger<AdminDashboardService> _logger;

    public AdminDashboardService(
        IUserRepository userRepository,
        ISubjectRepository subjectRepository,
        IDocumentRepository documentRepository,
        IChatRepository chatRepository,
        IEvaluationQuestionRepository evaluationQuestionRepository,
        IRagasBenchmarkResultRepository ragasBenchmarkResultRepository,
        ILogger<AdminDashboardService> logger)
    {
        _userRepository = userRepository;
        _subjectRepository = subjectRepository;
        _documentRepository = documentRepository;
        _chatRepository = chatRepository;
        _evaluationQuestionRepository = evaluationQuestionRepository;
        _ragasBenchmarkResultRepository = ragasBenchmarkResultRepository;
        _logger = logger;
    }

    public async Task<AdminDashboardDto> GetDashboardAsync(
        CancellationToken cancellationToken = default)
    {
        try
        {
            var users = await _userRepository.GetAllAsync(cancellationToken);
            var subjects = await _subjectRepository.GetAllAsync(cancellationToken);
            var documents = await _documentRepository.GetListAsync(cancellationToken: cancellationToken);

            var adminCount = users.Count(user =>
                string.Equals(user.Role, UserRoleNames.Admin, StringComparison.OrdinalIgnoreCase));
            var teacherCount = users.Count(user =>
                string.Equals(user.Role, UserRoleNames.Teacher, StringComparison.OrdinalIgnoreCase));
            var studentCount = users.Count(user =>
                string.Equals(user.Role, UserRoleNames.Student, StringComparison.OrdinalIgnoreCase));

            var indexedCount = documents.Count(doc => doc.Status == DocumentStatus.Indexed);
            var processingCount = documents.Count(doc => doc.Status == DocumentStatus.Processing);
            var failedCount = documents.Count(doc => doc.Status == DocumentStatus.Failed);

            var pdfCount = documents.Count(doc =>
                string.Equals(doc.FileType, ".pdf", StringComparison.OrdinalIgnoreCase));
            var docxCount = documents.Count(doc =>
                string.Equals(doc.FileType, ".docx", StringComparison.OrdinalIgnoreCase));
            var pptxCount = documents.Count(doc =>
                string.Equals(doc.FileType, ".pptx", StringComparison.OrdinalIgnoreCase));

            var recentDocuments = documents
                .OrderByDescending(doc => doc.UploadedAt)
                .Take(5)
                .Select(doc => new RecentDocumentDto(
                    doc.Id,
                    doc.Title,
                    doc.FileType,
                    doc.Subject.SubjectName,
                    doc.Status.ToString(),
                    doc.UploadedAt))
                .ToList();

            var chatSessionCount = await _chatRepository.CountSessionsAsync(cancellationToken);
            var chatMessageCount = await _chatRepository.CountMessagesAsync(cancellationToken);
            var evaluationQuestionCount = await _evaluationQuestionRepository.GetTotalAsync(cancellationToken);
            var benchmarkCount = await _ragasBenchmarkResultRepository.GetTotalAsync(cancellationToken);

            var recentBenchmarks = (await _ragasBenchmarkResultRepository.GetRecentAsync(5, cancellationToken))
                .Select(result => new RecentBenchmarkDto(
                    result.Id,
                    result.EvaluationQuestion.Subject.SubjectName,
                    result.EmbeddingModel,
                    result.LlmModel,
                    result.RecallAt5,
                    result.CreatedAt))
                .ToList();

            return new AdminDashboardDto(
                StudentCount: studentCount,
                TeacherCount: teacherCount,
                AdminCount: adminCount,
                SubjectCount: subjects.Count,
                TotalDocumentCount: documents.Count,
                IndexedDocumentCount: indexedCount,
                ProcessingDocumentCount: processingCount,
                FailedDocumentCount: failedCount,
                PdfCount: pdfCount,
                DocxCount: docxCount,
                PptxCount: pptxCount,
                EvaluationQuestionCount: evaluationQuestionCount,
                BenchmarkRunCount: benchmarkCount,
                ChatSessionCount: chatSessionCount,
                ChatMessageCount: chatMessageCount,
                RecentDocuments: recentDocuments,
                RecentBenchmarks: recentBenchmarks);
        }
        catch (Exception exception)
        {
            _logger.LogError(exception, "Failed to load admin dashboard data");
            throw;
        }
    }
}
