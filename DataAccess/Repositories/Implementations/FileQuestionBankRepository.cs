using System.Text.Json;
using BusinessObject.Entities;
using DataAccess.Repositories.Interfaces;

namespace DataAccess.Repositories.Implementations;

// Single shared local volume, immutable packages and atomic publication markers.
// Replace through IQuestionBankRepository when B02 persistence is agreed.
public sealed class FileQuestionBankRepository(string root) : IQuestionBankRepository
{
    private readonly string _root = Path.GetFullPath(root);
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private string PackagePath(Guid id, string version)
    {
        if (string.IsNullOrWhiteSpace(version) || version.Length > 64 ||
            version.Any(c => !char.IsAsciiLetterOrDigit(c) && c != '.' && c != '-' && c != '_'))
            throw new ArgumentException("Invalid package version.", nameof(version));
        return Path.Combine(_root, $"{id:N}-{version}.json");
    }

    public async Task<QuestionBankPackage?> GetAsync(Guid id, string version, CancellationToken cancellationToken = default)
    {
        var path = PackagePath(id, version);
        if (!File.Exists(path)) return null;
        await using var stream = File.OpenRead(path);
        var package = await JsonSerializer.DeserializeAsync<QuestionBankPackage>(stream, Json, cancellationToken)
            ?? throw new InvalidDataException("Empty bank package.");
        var hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(package.Bank)));
        if (hash != package.Hash) throw new InvalidDataException("Bank content hash mismatch.");
        var marker = path + ".published";
        if (!File.Exists(marker)) return package;
        var publication = JsonSerializer.Deserialize<Publication>(await File.ReadAllTextAsync(marker, cancellationToken), Json)
            ?? throw new InvalidDataException("Invalid publication marker.");
        if (publication.Hash != package.Hash) throw new InvalidDataException("Publication hash mismatch.");
        return package with { IsPublished = true, PublishedAt = publication.CreatedAt };
    }

    public async Task<IReadOnlyList<QuestionBankPackage>> ListAsync(CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(_root);
        var packages = new List<QuestionBankPackage>();
        foreach (var path in Directory.EnumerateFiles(_root, "*.json"))
        {
            cancellationToken.ThrowIfCancellationRequested();
            await using var stream = File.OpenRead(path);
            var item = await JsonSerializer.DeserializeAsync<QuestionBankPackage>(stream, Json, cancellationToken)
                ?? throw new InvalidDataException("Empty bank package.");
            packages.Add((await GetAsync(item.Bank.Id, item.Bank.Version, cancellationToken))!);
        }
        return packages;
    }

    public Task<bool> AddAsync(QuestionBankPackage package, CancellationToken cancellationToken = default) =>
        WriteOnceAsync(PackagePath(package.Bank.Id, package.Bank.Version), package, cancellationToken);

    public async Task<bool> PublishAsync(Guid id, string version, string expectedHash, CancellationToken cancellationToken = default)
    {
        var package = await GetAsync(id, version, cancellationToken);
        if (package is null || package.Hash != expectedHash) return false;
        if (package.IsPublished) return true;
        var marker = PackagePath(id, version) + ".published";
        return await WriteOnceAsync(marker, new Publication(expectedHash, DateTime.UtcNow), cancellationToken)
            || (await GetAsync(id, version, cancellationToken))?.IsPublished == true;
    }

    private async Task<bool> WriteOnceAsync<T>(string path, T value, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(_root);
        var temporary = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            await using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None,
                4096, FileOptions.WriteThrough | FileOptions.Asynchronous))
            {
                await JsonSerializer.SerializeAsync(stream, value, Json, cancellationToken);
                await stream.FlushAsync(cancellationToken);
            }
            try { File.Move(temporary, path, overwrite: false); return true; }
            catch (IOException) when (File.Exists(path)) { return false; }
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    private sealed record Publication(string Hash, DateTime CreatedAt);
}
