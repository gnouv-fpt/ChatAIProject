using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure;
using BusinessLogic.Services.Interfaces;
using BusinessObject.Entities;
using BusinessObject.Enums;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed record ExtendReviewedCorpusRequest(ImportCapturedLegalCorpusRequest Capture,
    string ExpectedCurrentHash, int ExpectedCurrentVersion);
public sealed record ExtendReviewedCorpusResult(Guid DocumentId, int Version, int ChunkCount,
    int AddedChunkCount, string ContentHash, bool IsActive);

// Local edition expansion. SQL becomes ineligible before vector replacement; retries resume
// the same staged edition after a partial Qdrant or SQL failure.
public sealed class LegalCorpusExtensionService(IDocumentRepository documents,
    IGenericRepository<DocumentChunk> chunks, IGrpcInferenceService inference)
{
    public async Task<ExtendReviewedCorpusResult> ExtendAsync(ExtendReviewedCorpusRequest request, CancellationToken ct)
    {
        var capture = request.Capture;
        var firstArticle = request.ExpectedCurrentVersion switch { 1 => 34, 2 => 50, 3 => 56, _ => 0 };
        var lastArticle = request.ExpectedCurrentVersion switch { 1 => 49, 2 => 55, 3 => 89, _ => 0 };
        if (capture is null || capture.DocumentNumber != "55/VBHN-VPQH" ||
            firstArticle == 0 || capture.Articles is null ||
            !capture.Articles.SequenceEqual(Enumerable.Range(firstArticle, lastArticle - firstArticle + 1).Select(n => n.ToString())) ||
            capture.Articles.Distinct().Count() != capture.Articles.Count ||
            capture.Articles.Any(a => !System.Text.RegularExpressions.Regex.IsMatch(a, "^[1-9][0-9]{0,2}$")) ||
            !Uri.TryCreate(capture.SourceUrl, UriKind.Absolute, out var url) || !LegalContentParser.IsAllowedSource(url) ||
            !Uri.TryCreate(capture.OfficialSourceUrl, UriKind.Absolute, out var official) || official.Scheme != "https" ||
            official.Host != "datafiles.chinhphu.vn" || !official.IsDefaultPort || !string.IsNullOrEmpty(official.UserInfo) ||
            string.IsNullOrWhiteSpace(capture.ReviewNotes) || capture.Content is not { Length: >= 100 and <= 2000000 } ||
            request.ExpectedCurrentVersion < 1 || string.IsNullOrWhiteSpace(request.ExpectedCurrentHash))
            throw new BadRequestException("Gói mở rộng hoặc thông tin đối chiếu không hợp lệ.");
        var sourceHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(capture.Content)));
        if (!sourceHash.Equals(capture.ContentSha256, StringComparison.OrdinalIgnoreCase))
            throw new ConflictException("Hash nội dung nguồn không khớp.");
        var selected = LegalContentParser.Chunk(capture.Content);
        if (selected.Count == 0 || selected.Any(c => c.Article is null || !capture.Articles.Contains(c.Article)) ||
            capture.Articles.Any(a => !selected.Any(c => c.Article == a)))
            throw new BadRequestException("Nội dung không khớp phạm vi Điều đã rà soát.");
        var extensionHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            JsonSerializer.Serialize(selected.Select(c => new { c.Article, c.Clause, c.Point, c.Content })))));
        var document = (await documents.FindAsync(d => d.DocumentNumber == capture.DocumentNumber, ct)).SingleOrDefault()
            ?? throw new NotFoundException("Không tìm thấy văn bản gốc cần mở rộng.");
        if (document.SourceUrl != capture.SourceUrl || document.EffectiveDate is null ||
            document.EffectiveDate > DateTime.UtcNow || document.ExpirationDate <= DateTime.UtcNow)
            throw new ConflictException("Văn bản gốc chưa đủ điều kiện hiệu lực hoặc nguồn đã đổi.");
        var targetHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            request.ExpectedCurrentHash.ToUpperInvariant() + ":" + extensionHash)));
        var targetVersion = checked(request.ExpectedCurrentVersion + 1);
        var rows = await chunks.FindAsync(c => c.DocumentId == document.Id, ct);
        if (request.ExpectedCurrentVersion == 3)
            return await ExtendWithoutDisablingCurrentAsync(document, rows, selected, capture,
                request.ExpectedCurrentHash, targetHash, targetVersion, ct);
        var staged = document.Version == targetVersion && document.ContentHash == targetHash;
        if (!staged)
        {
            if (!document.IsActive || document.VerificationStatus != VerificationStatus.Verified ||
                document.Version != request.ExpectedCurrentVersion ||
                !string.Equals(document.ContentHash, request.ExpectedCurrentHash, StringComparison.OrdinalIgnoreCase) ||
                rows.Any(c => !c.IsVerified || c.Article is null || capture.Articles.Contains(c.Article)) ||
                !Enumerable.Range(1, firstArticle - 1).All(n => rows.Any(c => c.Article == n.ToString())))
                throw new ConflictException("Phiên bản gốc hoặc phạm vi mở rộng đã thay đổi; cần rà soát lại.");
            var verification = await inference.VerifyLegalDocumentAsync(capture.DocumentTitle,
                capture.DocumentNumber, capture.Content, ct);
            if (!verification.IsValid || verification.Status != nameof(VerificationStatus.Verified))
                throw new ConflictException("Dịch vụ chưa xác minh được gói mở rộng.");
            document.IsActive = false;
            document.VerificationStatus = VerificationStatus.Pending;
            document.Version = targetVersion;
            document.ContentHash = targetHash;
            document.Title = $"Luật Trật tự, an toàn giao thông đường bộ · VBHN 55/2026 · trích Điều 1–{lastArticle}";
            documents.Update(document);
            foreach (var row in rows) { row.IsVerified = false; chunks.Update(row); }
            var added = new List<DocumentChunk>();
            foreach (var item in selected)
            {
                var chunk = new DocumentChunk { Id = Guid.NewGuid(), DocumentId = document.Id,
                    Article = item.Article, Clause = item.Clause, Point = item.Point, Content = item.Content,
                    IsVerified = false };
                await chunks.AddAsync(chunk, ct);
                added.Add(chunk);
            }
            await documents.SaveChangesAsync(ct);
            rows = rows.Concat(added).ToArray();
        }
        else if (document.IsActive && document.VerificationStatus == VerificationStatus.Verified)
            return new(document.Id, document.Version, rows.Count, selected.Count, targetHash, true);
        else if (document.IsActive || document.VerificationStatus != VerificationStatus.Pending ||
                 rows.Count(c => capture.Articles.Contains(c.Article ?? "")) != selected.Count ||
                 !rows.Where(c => capture.Articles.Contains(c.Article ?? ""))
                     .Select(c => JsonSerializer.Serialize(new { c.Article, c.Clause, c.Point, c.Content }))
                     .Order(StringComparer.Ordinal).SequenceEqual(selected
                         .Select(c => JsonSerializer.Serialize(new { c.Article, c.Clause, c.Point, c.Content }))
                         .Order(StringComparer.Ordinal)))
            throw new ConflictException("Trạng thái edition mở rộng không khớp gói đã duyệt.");

        // SQL denies citations throughout both vector calls. Repeatable after a partial failure.
        if (!staged)
            await inference.DeactivateDocumentAsync(document.DocumentNumber, ct);
        var indexed = await inference.IndexDocumentAsync(rows.Select(c => new DocumentChunkInputDto {
            DocumentId = document.Id.ToString(), DocumentVersion = document.Version.ToString(),
            ChunkId = c.Id.ToString(), DocumentTitle = document.Title, DocumentNumber = document.DocumentNumber,
            Article = c.Article ?? "", Clause = c.Clause ?? "", Point = c.Point ?? "", Chapter = c.Chapter ?? "",
            Content = c.Content, ContentHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(c.Content))).ToLowerInvariant(),
            SourceUrl = document.SourceUrl!, IsVerified = true, IsActive = true
        }), ct);
        if (!indexed.Success || indexed.IndexedCount != rows.Count)
            throw new ServiceUnavailableException("Chưa lập chỉ mục đủ chunks; có thể chạy lại cùng gói.");
        foreach (var row in rows) { row.IsVerified = true; row.VectorId = QdrantPointIds.FromChunkId(row.Id); chunks.Update(row); }
        document.IsActive = true;
        document.VerificationStatus = VerificationStatus.Verified;
        document.LastVerifiedAt = DateTime.UtcNow;
        documents.Update(document);
        await documents.SaveChangesAsync(ct);
        return new(document.Id, document.Version, rows.Count, selected.Count, targetHash, true);
    }

    private async Task<ExtendReviewedCorpusResult> ExtendWithoutDisablingCurrentAsync(
        LegalDocument document, IReadOnlyList<DocumentChunk> rows, IReadOnlyList<LegalChunk> selected,
        ImportCapturedLegalCorpusRequest capture, string expectedHash, string targetHash, int targetVersion,
        CancellationToken ct)
    {
        var old = rows.Where(c => c.Article is not null && int.TryParse(c.Article, out var n) && n <= 55).ToArray();
        var added = rows.Where(c => c.Article is not null && capture.Articles.Contains(c.Article)).ToArray();
        if (old.Length != 596 || !Enumerable.Range(1, 55).All(n => old.Any(c => c.Article == n.ToString())) ||
            old.Any(c => !c.IsVerified) || added.Length != 0 && added.Length != selected.Count ||
            document.Version == targetVersion && added.Length != selected.Count ||
            rows.Count != old.Length + added.Length ||
            document.Version != 3 && document.Version != targetVersion ||
            document.Version == 3 && (!document.IsActive || document.VerificationStatus != VerificationStatus.Verified ||
                !string.Equals(document.ContentHash, expectedHash, StringComparison.OrdinalIgnoreCase)) ||
            document.Version == targetVersion && (!document.IsActive || document.VerificationStatus != VerificationStatus.Verified ||
                document.ContentHash != targetHash))
            throw new ConflictException("Edition hiện hành hoặc gói mở rộng không khớp; giữ corpus đang phục vụ.");
        if (added.Length != 0 && !added.Select(c => JsonSerializer.Serialize(new { c.Article, c.Clause, c.Point, c.Content }))
            .Order(StringComparer.Ordinal).SequenceEqual(selected.Select(c => JsonSerializer.Serialize(
                new { c.Article, c.Clause, c.Point, c.Content })).Order(StringComparer.Ordinal)))
            throw new ConflictException("Chunks đã staging khác gói được duyệt.");
        if (document.Version == targetVersion && added.Length == selected.Count &&
            added.All(c => c.IsVerified && c.VectorId == QdrantPointIds.FromChunkId(c.Id)))
        {
            await UpdateEditionFourTitleAsync(document, rows, targetVersion, ct);
            if (!await inference.VerifyDocumentIndexAsync(rows.Select(c => ToInput(c, document, targetVersion, true)), ct))
                throw new ServiceUnavailableException("Chỉ mục không còn khớp SQL; giữ corpus hiện hành và cần đối soát lại.");
            return new(document.Id, targetVersion, rows.Count, added.Length, targetHash, true);
        }

        if (added.Length == 0)
        {
            var verification = await inference.VerifyLegalDocumentAsync(capture.DocumentTitle,
                capture.DocumentNumber, capture.Content, ct);
            if (!verification.IsValid || verification.Status != nameof(VerificationStatus.Verified))
                throw new ConflictException("Dịch vụ chưa xác minh được gói mở rộng.");
            foreach (var item in selected)
                await chunks.AddAsync(new DocumentChunk { Id = Guid.NewGuid(), DocumentId = document.Id,
                    Article = item.Article, Clause = item.Clause, Point = item.Point,
                    Content = item.Content, IsVerified = false }, ct);
            await documents.SaveChangesAsync(ct);
            rows = await chunks.FindAsync(c => c.DocumentId == document.Id, ct);
            added = rows.Where(c => c.Article is not null && capture.Articles.Contains(c.Article)).ToArray();
        }

        // The existing 596 chunks and their vectors remain eligible throughout staging and retry.
        // Keep the document title stable so citations from the current vectors remain valid.
        if (document.Version == 3)
        {
            var staged = await inference.IndexDocumentAsync(added.Select(c => ToInput(c, document, targetVersion, false)), ct);
            if (!staged.Success || staged.IndexedCount != added.Length)
                throw new ServiceUnavailableException("Chưa staging đủ vectors; corpus cũ vẫn hoạt động. Chạy lại cùng gói.");
            document.Version = targetVersion;
            document.ContentHash = targetHash;
            documents.Update(document);
            foreach (var row in added)
            {
                row.IsVerified = true;
                chunks.Update(row);
            }
            await documents.SaveChangesAsync(ct);
        }
        // A retry may follow a partial activation. Restore every new point to inactive first.
        var restaged = await inference.IndexDocumentAsync(added.Select(c => ToInput(c, document, targetVersion, false)), ct);
        if (!restaged.Success || restaged.IndexedCount != added.Length)
            throw new ServiceUnavailableException("Chưa staging đủ vectors mới; corpus cũ vẫn hoạt động. Chạy lại cùng gói.");
        var refreshed = await inference.IndexDocumentAsync(old.Select(c => ToInput(c, document, targetVersion, true)), ct);
        if (!refreshed.Success || refreshed.IndexedCount != old.Length)
            throw new ServiceUnavailableException("Chưa đồng bộ metadata vectors cũ; corpus cũ vẫn hoạt động. Chạy lại cùng gói.");
        if (!await inference.VerifyDocumentIndexAsync(rows.Select(c => ToInput(c, document, targetVersion,
                !added.Any(a => a.Id == c.Id))), ct))
            throw new ServiceUnavailableException("SQL và Qdrant chưa khớp trước khi bật vectors mới; corpus cũ vẫn hoạt động.");
        var activated = await inference.IndexDocumentAsync(added.Select(c => ToInput(c, document, targetVersion, true)), ct);
        if (!activated.Success || activated.IndexedCount != added.Length)
            throw new ServiceUnavailableException("Chưa bật đủ vectors mới; corpus cũ vẫn hoạt động. Chạy lại cùng gói.");
        if (!await inference.VerifyDocumentIndexAsync(rows.Select(c => ToInput(c, document, targetVersion, true)), ct))
            throw new ServiceUnavailableException("SQL và Qdrant chưa khớp toàn bộ; corpus cũ vẫn hoạt động. Chạy lại cùng gói.");
        foreach (var row in added) { row.VectorId = QdrantPointIds.FromChunkId(row.Id); chunks.Update(row); }
        await documents.SaveChangesAsync(ct);
        await UpdateEditionFourTitleAsync(document, rows, targetVersion, ct);
        return new(document.Id, targetVersion, rows.Count, added.Length, targetHash, true);
    }

    private async Task UpdateEditionFourTitleAsync(LegalDocument document, IReadOnlyList<DocumentChunk> rows,
        int version, CancellationToken ct)
    {
        if (document.Title.Contains("Điều 1–89", StringComparison.Ordinal)) return;
        if (!document.Title.Contains("Điều 1–55", StringComparison.Ordinal))
            throw new ConflictException("Tên corpus không khớp phạm vi trước khi cập nhật edition 4.");
        var previousTitle = document.Title;
        document.Title = previousTitle.Replace("Điều 1–55", "Điều 1–89", StringComparison.Ordinal);
        var refreshed = await inference.IndexDocumentAsync(rows.Select(c => ToInput(c, document, version, true)), ct);
        if (!refreshed.Success || refreshed.IndexedCount != rows.Count)
            throw new ServiceUnavailableException("Chưa đồng bộ tên văn bản trong vector; corpus vẫn hoạt động. Chạy lại cùng gói.");
        if (!await inference.VerifyDocumentIndexAsync(rows.Select(c => ToInput(c, document, version, true)), ct))
            throw new ServiceUnavailableException("Tên văn bản trong SQL và vector chưa khớp; chạy lại cùng gói.");
        documents.Update(document);
        await documents.SaveChangesAsync(ct);
    }

    private static DocumentChunkInputDto ToInput(DocumentChunk chunk, LegalDocument document, int version, bool active) => new()
    {
        DocumentId = document.Id.ToString(), DocumentVersion = version.ToString(), ChunkId = chunk.Id.ToString(),
        DocumentTitle = document.Title, DocumentNumber = document.DocumentNumber, Article = chunk.Article ?? "",
        Clause = chunk.Clause ?? "", Point = chunk.Point ?? "", Chapter = chunk.Chapter ?? "",
        Content = chunk.Content, ContentHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(chunk.Content))).ToLowerInvariant(),
        SourceUrl = document.SourceUrl!, IsVerified = true, IsActive = active
    };
}
