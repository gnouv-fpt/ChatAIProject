using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Controllers;

[ApiController, Route("api/exam-templates"), Authorize]
public sealed class ExamTemplatesController(IQuestionBankService service) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellationToken) =>
        Ok((await service.ListAsync(false, cancellationToken)).Select(b => new {
            BankId = b.Id, BankVersion = b.Version, BankHash = b.Hash, Profile = b.Profile }));
}
