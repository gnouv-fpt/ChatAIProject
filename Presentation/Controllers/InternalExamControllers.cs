using BusinessLogic.Exams;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;
using Presentation.Infrastructure;

namespace Presentation.Controllers;

[ApiController, ServiceModule("Content"), Route("internal/content/exam-questions"), Authorize(Policy = "ContentRead")]
public sealed class InternalExamQuestionsController(ExamIntegrationService service) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(string categoryId, string bankVersion, int count, CancellationToken ct) =>
        Ok(await service.GetPoolAsync(categoryId, bankVersion, count, ct));
}

[ApiController, ServiceModule("Content"), Route("internal/content/exam-template-questions"), Authorize(Policy = "ContentRead")]
public sealed class InternalExamTemplateQuestionsController(ExamIntegrationService service) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(string code, int version, CancellationToken ct) =>
        Ok(await service.GetTemplateAsync(code, version, ct));
}

[ApiController, Route("internal/user/exam-results"), Authorize(Policy = "ExamWrite")]
public sealed class InternalExamResultsController(ExamResultService service) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Save(SaveExamResult result, CancellationToken ct)
    {
        await service.SaveAsync(result, ct);
        return Ok(new { result.AttemptId });
    }
}

[ApiController, Route("api/exam-attempts"), Authorize]
public sealed class ExamAttemptsController(ExamResultService service) : ControllerBase
{
    [HttpGet("{id:guid}/review")]
    public async Task<ActionResult<ExamAttemptReview>> Review(Guid id, CancellationToken ct) =>
        Ok(await service.GetReviewAsync(User.GetUserId(), id, ct));

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct) =>
        Ok(await service.GetOwnedAsync(User.GetUserId(), id, ct));
}

[ApiController, ServiceModule("Content"), Route("internal/content/learning-catalog"), Authorize(Policy = "ContentRead")]
public sealed class InternalLearningCatalogController(BusinessLogic.Services.Implementations.LearningCatalogService service) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct) => Ok(await service.GetAsync(ct));
}

[ApiController, ServiceModule("Content"), Route("internal/content/maintenance"), Authorize(Policy = "ContentMaintenance")]
public sealed class InternalContentMaintenanceController(BusinessLogic.Services.Interfaces.IContentMaintenanceService service) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Run(CancellationToken ct) => Ok(await service.RunAsync(ct));
}
