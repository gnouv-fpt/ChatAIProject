using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed record ImportLegalCorpusRequest(string SourceUrl, string ExpectedSourceContentHash,
    IReadOnlyList<string> Articles, string ReviewNotes);
public sealed record LegalCorpusImportResult(Guid DocumentId, int ChunkCount, string ContentHash, string Scope);
public sealed record ImportCapturedLegalCorpusRequest(string SourceUrl, string DocumentNumber, string DocumentTitle,
    string Content, string ContentSha256, IReadOnlyList<string> Articles, string OfficialSourceUrl, string ReviewNotes);

// Imports the exact reviewed scope as Pending. Activation still requires the separate verification/index API.
public sealed class LegalCorpusService(ILegalSourcePreviewService source, IDocumentRepository documents,
    IGenericRepository<DocumentChunk> chunks)
{
    public async Task<LegalCorpusImportResult> ImportAsync(ImportLegalCorpusRequest request, CancellationToken ct)
    {
        if (request.Articles is not { Count: > 0 and <= 200 } || request.Articles.Distinct().Count() != request.Articles.Count ||
            request.Articles.Any(a => string.IsNullOrWhiteSpace(a) || !System.Text.RegularExpressions.Regex.IsMatch(a, "^[1-9][0-9]{0,2}[a-zđ]?$")) ||
            string.IsNullOrWhiteSpace(request.ReviewNotes) || request.ReviewNotes.Length > 2000)
            throw new BadRequestException("Cần phạm vi Điều không trùng và ghi chú đối chiếu nguồn/hiệu lực.");
        var evidence = await source.PreviewAsync(request.SourceUrl, ct);
        if (!string.Equals(evidence.ContentSha256, request.ExpectedSourceContentHash, StringComparison.OrdinalIgnoreCase))
            throw new ConflictException("Nguồn đã thay đổi so với bản duyệt. Cần xem lại trước khi import.");
        return await PersistAsync(evidence, request.Articles, ct);
    }

    public Task<LegalCorpusImportResult> ImportCapturedAsync(ImportCapturedLegalCorpusRequest request, CancellationToken ct)
    {
        if (!Uri.TryCreate(request.SourceUrl, UriKind.Absolute, out var uri) || !LegalContentParser.IsAllowedSource(uri) ||
            !Uri.TryCreate(request.OfficialSourceUrl, UriKind.Absolute, out var official) || official.Scheme != "https" ||
            official.Host != "datafiles.chinhphu.vn" || !string.IsNullOrEmpty(official.UserInfo) || !official.IsDefaultPort ||
            string.IsNullOrWhiteSpace(request.DocumentNumber) || request.DocumentNumber.Length > 100 ||
            string.IsNullOrWhiteSpace(request.DocumentTitle) || request.DocumentTitle.Length > 300 ||
            request.Content is not { Length: >= 100 and <= 2000000 } || string.IsNullOrWhiteSpace(request.ReviewNotes) ||
            request.Articles is not { Count: > 0 and <= 200 } || request.Articles.Any(a => string.IsNullOrWhiteSpace(a)) ||
            request.Articles.Distinct().Count() != request.Articles.Count)
            throw new BadRequestException("Cần nội dung công khai TVPL, nguồn Chính phủ đối chiếu và phạm vi đã duyệt.");
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(request.Content)));
        if (!string.Equals(hash, request.ContentSha256, StringComparison.OrdinalIgnoreCase))
            throw new ConflictException("Hash nội dung bản thu nhận không khớp.");
        var parsed = LegalContentParser.Chunk(request.Content);
        if (parsed.Any(c => c.Article is null || !request.Articles.Contains(c.Article)))
            throw new BadRequestException("Nội dung nằm ngoài phạm vi đã duyệt.");
        var evidence = new BusinessLogic.DTOs.LegalSourceEvidenceDto(request.SourceUrl, DateTime.UtcNow, "", hash,
            request.DocumentNumber, request.DocumentTitle, request.Content,
            parsed.Select((c, n) => new BusinessLogic.DTOs.LegalChunkPreviewDto(n, c.Article, c.Clause, c.Point, c.Content)).ToArray());
        return PersistAsync(evidence, request.Articles, ct);
    }

    private async Task<LegalCorpusImportResult> PersistAsync(BusinessLogic.DTOs.LegalSourceEvidenceDto evidence,
        IReadOnlyList<string> articles, CancellationToken ct)
    {
        var selected = evidence.Chunks.Where(c => c.Article is not null && articles.Contains(c.Article)).ToArray();
        if (selected.Length == 0 || articles.Any(a => !selected.Any(c => c.Article == a)))
            throw new BadRequestException("Không trích xuất đủ các Điều đã chọn; không nhập gói thiếu.");
        var scope = "trích Điều " + string.Join(", ", articles);
        var title = evidence.Title + " · " + scope;
        if (title.Length > 500) throw new BadRequestException("Phạm vi/tên văn bản vượt giới hạn lưu trữ.");
        var canonical = JsonSerializer.Serialize(selected.Select(c => new { c.Article, c.Clause, c.Point, c.Content }));
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
        var existing = (await documents.FindAsync(d => d.DocumentNumber == evidence.DocumentNumber, ct)).SingleOrDefault();
        if (existing is not null)
        {
            var rows = await chunks.FindAsync(c => c.DocumentId == existing.Id, ct);
            if (existing.ContentHash != hash || existing.SourceUrl != evidence.SourceUrl || rows.Count != selected.Length)
                throw new ConflictException("Văn bản đã có với phạm vi/nội dung khác; không ghi đè dữ liệu đang dùng.");
            return new(existing.Id, rows.Count, hash, scope);
        }
        var document = new LegalDocument { Id = Guid.NewGuid(), DocumentNumber = evidence.DocumentNumber,
            Title = title, SourceUrl = evidence.SourceUrl, ContentHash = hash, CreatedAt = DateTime.UtcNow,
            VerificationStatus = VerificationStatus.Pending, IsActive = false };
        await documents.AddAsync(document, ct);
        foreach (var item in selected)
            await chunks.AddAsync(new DocumentChunk { Id = Guid.NewGuid(), DocumentId = document.Id,
                Article = item.Article, Clause = item.Clause, Point = item.Point, Content = item.Content, IsVerified = false }, ct);
        await documents.SaveChangesAsync(ct);
        return new(document.Id, selected.Length, hash, scope);
    }
}
