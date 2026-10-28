using System.Net;
using System.Security.Cryptography;
using System.Text;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Services.Interfaces;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services.Implementations;

public sealed class LegalSourcePreviewService(HttpClient client, ILogger<LegalSourcePreviewService> logger) : ILegalSourcePreviewService
{
    private const int MaximumBytes = 8 * 1024 * 1024;
    public async Task<LegalSourceEvidenceDto> PreviewAsync(string sourceUrl, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(sourceUrl) || sourceUrl.Length > 1000 ||
            !Uri.TryCreate(sourceUrl, UriKind.Absolute, out var uri) || !LegalContentParser.IsAllowedSource(uri))
            throw new BadRequestException("Chỉ chấp nhận HTTPS thuvienphapluat.vn/van-ban, không có thông tin đăng nhập hoặc query.");
        try
        {
            using var response = await client.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if ((int)response.StatusCode is >= 300 and <= 399)
                throw new BadRequestException("Nguồn chuyển hướng. Hãy kiểm tra và dùng URL văn bản đích thuộc phạm vi cho phép.");
            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Legal source returned HTTP {StatusCode} for {SourceUrl}", (int)response.StatusCode, uri.AbsoluteUri);
                throw new AppException(502, "Không thể đọc nguồn văn bản. Vui lòng kiểm tra quyền truy cập hoặc thử lại.");
            }
            if (response.RequestMessage?.RequestUri is Uri final && final != uri)
                throw new BadRequestException("HTTP client không được tự theo chuyển hướng khi đọc nguồn.");
            if (response.Content.Headers.ContentType?.MediaType is not ("text/html" or "application/xhtml+xml"))
                throw new BadRequestException("Nguồn phải trả về HTML văn bản.");
            if (response.Content.Headers.ContentLength > MaximumBytes) throw new BadRequestException("Nguồn vượt giới hạn 8 MB.");
            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var buffer = new MemoryStream();
            var bytes = new byte[8192];
            int count;
            while ((count = await stream.ReadAsync(bytes, cancellationToken)) > 0)
            {
                if (buffer.Length + count > MaximumBytes) throw new BadRequestException("Nguồn vượt giới hạn 8 MB.");
                await buffer.WriteAsync(bytes.AsMemory(0, count), cancellationToken);
            }
            var htmlBytes = buffer.ToArray();
            var charset = response.Content.Headers.ContentType?.CharSet?.Trim('"');
            if (charset is not null && !charset.Equals("utf-8", StringComparison.OrdinalIgnoreCase))
                throw new BadRequestException("Nguồn cần mã hóa UTF-8 để tránh sai nội dung tiếng Việt.");
            string html;
            try { html = new UTF8Encoding(false, true).GetString(htmlBytes); }
            catch (DecoderFallbackException) { throw new BadRequestException("Nội dung nguồn không phải UTF-8 hợp lệ."); }
            var parsed = LegalContentParser.Parse(html);
            var chunks = LegalContentParser.Chunk(parsed.Content);
            if (chunks.Count == 0) throw new BadRequestException("Không tách được Điều luật từ nguồn.");
            logger.LogInformation("Legal source preview: {SourceUrl}, {ChunkCount} chunks, {Bytes} bytes", uri.AbsoluteUri, chunks.Count, htmlBytes.Length);
            return new(uri.AbsoluteUri, DateTime.UtcNow, Convert.ToHexString(SHA256.HashData(htmlBytes)),
                Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(parsed.Content))), parsed.Number, parsed.Title,
                parsed.Content, chunks.Select((chunk, sequence) => new LegalChunkPreviewDto(sequence, chunk.Article, chunk.Clause, chunk.Point, chunk.Content)).ToList());
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
        catch (OperationCanceledException exception)
        {
            logger.LogWarning(exception, "Legal source preview timed out");
            throw new AppException(504, "Nguồn văn bản phản hồi quá thời hạn. Vui lòng thử lại.");
        }
        catch (HttpRequestException exception)
        {
            logger.LogWarning(exception, "Legal source preview connection failed");
            throw new AppException(502, "Không kết nối được nguồn văn bản. Vui lòng thử lại.");
        }
    }
}
