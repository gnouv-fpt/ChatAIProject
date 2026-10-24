using System.Security.Cryptography;
using System.Text.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Exceptions;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Interfaces;
using DataAccess.Repositories.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class PrivateAttachmentService(ChatSettings settings, IChatSessionRepository sessions) : IAttachmentService
{
    private sealed record Metadata(Guid UserId, Guid SessionId, Guid Id, string MimeType, long Size, string Hash, DateTime ExpiresAt);
    private string Root => Path.GetFullPath(settings.AttachmentRoot);
    private string Folder(Guid userId) => Path.Combine(Root, userId.ToString("N"));
    private string FilePath(Guid userId, Guid id, string extension) => Path.Combine(Folder(userId), id.ToString("N") + extension);

    private async Task EnsureSessionAsync(Guid userId, Guid sessionId, CancellationToken ct)
    {
        var session = await sessions.GetByIdAsync(sessionId, ct);
        if (session == null || session.UserId != userId || session.IsDeleted)
            throw new NotFoundException("Không tìm thấy phiên chat.");
    }

    public async Task<AttachmentResponseDto> UploadAsync(Guid userId, Guid sessionId, string mimeType, Stream content, CancellationToken ct)
    {
        await EnsureSessionAsync(userId, sessionId, ct);
        if (mimeType is not ("image/jpeg" or "image/png" or "image/webp"))
            throw new BadRequestException("Chỉ chấp nhận ảnh JPEG, PNG hoặc WebP.");
        // Read at most MaxAttachmentBytes + 1, regardless of the caller's Content-Length.
        using var buffer = new MemoryStream();
        var bytes = new byte[81920];
        int read;
        while ((read = await content.ReadAsync(bytes.AsMemory(0, Math.Min(bytes.Length, settings.MaxAttachmentBytes + 1 - (int)buffer.Length)), ct)) > 0)
        {
            await buffer.WriteAsync(bytes.AsMemory(0, read), ct);
            if (buffer.Length > settings.MaxAttachmentBytes) throw new BadRequestException("Ảnh vượt dung lượng cho phép.");
        }
        var data = buffer.ToArray();
        if (!HasSignature(data, mimeType)) throw new BadRequestException("Nội dung tệp không khớp định dạng ảnh.");
        Directory.CreateDirectory(Folder(userId));
        // Cross-process filesystem lock also bounds simultaneous upload quota checks.
        await using var quotaLock = await AcquireLockAsync(Path.Combine(Folder(userId), "upload.lock"), ct);
        var used = Directory.EnumerateFiles(Folder(userId), "*.bin").Sum(f => new FileInfo(f).Length);
        if (used + data.Length > settings.MaxUserAttachmentBytes)
            throw new QuotaExceededException("Dung lượng ảnh đã đầy. Hãy xóa ảnh cũ hoặc chờ hết hạn.");
        var id = Guid.NewGuid();
        var metadata = new Metadata(userId, sessionId, id, mimeType, data.Length,
            Convert.ToHexString(SHA256.HashData(data)), DateTime.UtcNow.AddHours(settings.AttachmentRetentionHours));
        try
        {
            await File.WriteAllBytesAsync(FilePath(userId, id, ".bin"), data, ct);
            await File.WriteAllTextAsync(FilePath(userId, id, ".tmp"), JsonSerializer.Serialize(metadata), ct);
            File.Move(FilePath(userId, id, ".tmp"), FilePath(userId, id, ".json"));
        }
        catch
        {
            File.Delete(FilePath(userId, id, ".bin"));
            File.Delete(FilePath(userId, id, ".tmp"));
            throw;
        }
        return new(id, sessionId, mimeType, data.Length, metadata.ExpiresAt);
    }

    private static async Task<FileStream> AcquireLockAsync(string path, CancellationToken ct)
    {
        for (var attempt = 0; ; attempt++)
        {
            ct.ThrowIfCancellationRequested();
            try { return new FileStream(path, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
            catch (IOException) when (attempt < 50) { await Task.Delay(100, ct); }
        }
    }

    public async Task<ChatImageDto> ReadAsync(Guid userId, Guid sessionId, Guid id, CancellationToken ct)
    {
        await EnsureSessionAsync(userId, sessionId, ct);
        try
        {
            var meta = JsonSerializer.Deserialize<Metadata>(await File.ReadAllTextAsync(FilePath(userId, id, ".json"), ct));
            if (meta == null || meta.UserId != userId || meta.SessionId != sessionId || meta.Id != id || meta.ExpiresAt <= DateTime.UtcNow)
                throw new NotFoundException("Ảnh không tồn tại hoặc đã hết hạn.");
            var data = await File.ReadAllBytesAsync(FilePath(userId, id, ".bin"), ct);
            if (data.Length != meta.Size || Convert.ToHexString(SHA256.HashData(data)) != meta.Hash)
                throw new ConflictException("Ảnh đã thay đổi. Vui lòng tải lại.");
            return new(id, meta.MimeType, data);
        }
        catch (FileNotFoundException) { throw new NotFoundException("Ảnh không tồn tại hoặc đã hết hạn."); }
        catch (DirectoryNotFoundException) { throw new NotFoundException("Không tìm thấy ảnh."); }
    }

    public async Task DeleteAsync(Guid userId, Guid sessionId, Guid id, CancellationToken ct)
    {
        await ReadAsync(userId, sessionId, id, ct);
        File.Delete(FilePath(userId, id, ".json"));
        File.Delete(FilePath(userId, id, ".bin"));
    }

    public Task CleanupAsync(CancellationToken ct)
    {
        if (!Directory.Exists(Root)) return Task.CompletedTask;
        foreach (var file in Directory.EnumerateFiles(Root, "*", SearchOption.AllDirectories))
        {
            ct.ThrowIfCancellationRequested();
            // All files for an upload are created together. Orphan bytes/metadata are also removed.
            if (Path.GetExtension(file) is ".bin" or ".json" or ".tmp" &&
                File.GetLastWriteTimeUtc(file) < DateTime.UtcNow.AddHours(-settings.AttachmentRetentionHours))
                File.Delete(file);
        }
        return Task.CompletedTask;
    }

    public static bool HasSignature(byte[] data, string mimeType) => mimeType switch
    {
        "image/png" => data.Length >= 24 && data.AsSpan(0, 8).SequenceEqual(new byte[] {137,80,78,71,13,10,26,10}) && data.AsSpan(12, 4).SequenceEqual("IHDR"u8),
        "image/jpeg" => data.Length >= 4 && data[0] == 255 && data[1] == 216 && data[2] == 255 && data[^2] == 255 && data[^1] == 217,
        "image/webp" => data.Length >= 16 && data.AsSpan(0, 4).SequenceEqual("RIFF"u8) && data.AsSpan(8, 4).SequenceEqual("WEBP"u8),
        _ => false
    };
}
