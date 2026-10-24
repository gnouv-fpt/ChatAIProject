using BusinessLogic.DTOs;
using BusinessLogic.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Presentation.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class DocumentsController : ControllerBase
{
    private readonly IDocumentService _documentService;
    private readonly ICrawlerService _crawlerService;

    public DocumentsController(IDocumentService documentService, ICrawlerService crawlerService)
    {
        _documentService = documentService;
        _crawlerService = crawlerService;
    }

    [HttpGet]
    public async Task<IActionResult> GetList(
        [FromQuery] DocumentFilterDto filter,
        CancellationToken cancellationToken)
    {
        var result = await _documentService.GetDocumentsAsync(filter, cancellationToken);
        return Ok(result);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id, CancellationToken cancellationToken)
    {
        var document = await _documentService.GetByIdAsync(id, cancellationToken);
        return document is null ? NotFound() : Ok(document);
    }

    [HttpPost("crawl-trigger")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> TriggerCrawl(CancellationToken cancellationToken)
    {
        await _crawlerService.CrawlTrafficLawsAsync(cancellationToken);
        return Accepted(new { message = "Tiến trình cào dữ liệu đã được kích hoạt." });
    }
}