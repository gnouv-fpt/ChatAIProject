using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Controllers;

[ApiController, Route("api/question-banks"), Authorize]
public sealed class QuestionBanksController(IQuestionBankService service) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellationToken) => Ok(await service.ListAsync(false, cancellationToken));

    [HttpGet("{id:guid}/versions/{version}/questions")]
    public async Task<IActionResult> Questions(Guid id, string version, CancellationToken cancellationToken,
        [FromQuery] string? topic = null, [FromQuery] int? from = null, [FromQuery] int? to = null,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 20) =>
        Ok(await service.GetQuestionsAsync(id, version, topic, from, to, page, pageSize, cancellationToken));
}
