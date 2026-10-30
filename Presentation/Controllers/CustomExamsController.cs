using BusinessLogic.Exams;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Presentation.Extensions;

namespace Presentation.Controllers;

[ApiController]
[Authorize]
[Route("api/custom-exams")]
public sealed class CustomExamsController(CustomExamService exams) : ControllerBase
{
    [HttpPost]
    public async Task<ActionResult<CustomExamView>> Create([FromBody] CreateCustomExam request,
        CancellationToken cancellationToken)
    {
        var created = await exams.CreateAsync(User.GetUserId(), request, cancellationToken);
        return CreatedAtAction(nameof(Get), new { examId = created.ExamId }, created);
    }

    [HttpGet("{examId:guid}")]
    public async Task<ActionResult<CustomExamView>> Get(Guid examId, CancellationToken cancellationToken) =>
        Ok(await exams.GetAsync(User.GetUserId(), examId, cancellationToken));

    [HttpPut("{examId:guid}/answers/{questionId}")]
    public async Task<ActionResult<CustomExamView>> Save(Guid examId, string questionId,
        [FromBody] SaveAnswerRequest request, CancellationToken cancellationToken) =>
        Ok(await exams.SaveAnswerAsync(User.GetUserId(), examId, questionId,
            request.OptionId, request.Revision, cancellationToken));

    [HttpPost("{examId:guid}/submit")]
    public async Task<ActionResult<ExamScore>> Submit(Guid examId, CancellationToken cancellationToken) =>
        Ok(await exams.SubmitAsync(User.GetUserId(), examId, cancellationToken));
}

public sealed record SaveAnswerRequest(string? OptionId, long Revision);
