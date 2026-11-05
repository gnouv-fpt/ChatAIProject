using System.Text.Json;
using BusinessLogic.Exams;

namespace Presentation.Exams;

public sealed class FileExamAnimationCatalog : IExamAnimationCatalog
{
    private readonly IReadOnlyDictionary<int, ExamAnimationSource> _items;

    public FileExamAnimationCatalog(IWebHostEnvironment environment)
    {
        var directory = ResolveDirectory(environment.ContentRootPath);
        using var bank = JsonDocument.Parse(File.ReadAllText(Path.Combine(directory, "bank.json")));
        using var scenes = JsonDocument.Parse(File.ReadAllText(Path.Combine(directory, "scenes.json")));
        using var release = JsonDocument.Parse(File.ReadAllText(Path.Combine(directory, "accepted-release.json")));

        var questions = bank.RootElement.GetProperty("questions").EnumerateArray()
            .ToDictionary(item => item.GetProperty("number").GetInt32(), item => item.Clone());
        var approved = release.RootElement.GetProperty("approvedRevisions");
        var result = new Dictionary<int, ExamAnimationSource>();

        foreach (var property in scenes.RootElement.GetProperty("scenes").EnumerateObject())
        {
            if (!int.TryParse(property.Name, out var number) || !questions.TryGetValue(number, out var question) ||
                !property.Value.TryGetProperty("revision", out var revision) ||
                !approved.TryGetProperty(property.Name, out var approvedRevision) ||
                revision.GetString() != approvedRevision.GetString()) continue;

            var images = question.GetProperty("images").EnumerateArray()
                .Select(image => new ExamAnimationImage(
                    image.GetProperty("url").GetString()!,
                    image.GetProperty("width").GetInt32(),
                    image.GetProperty("height").GetInt32()))
                .ToArray();
            var options = question.GetProperty("options").EnumerateArray()
                .Select(option => new ExamOption(
                    option.GetProperty("id").ToString(), option.GetProperty("text").GetString()!))
                .ToArray();
            var correctOptionIds = question.GetProperty("correctOptionIds").EnumerateArray()
                .Select(option => option.ToString()).ToArray();
            if (images.Length > 0) result[number] = new(number,
                question.GetProperty("prompt").GetString()!, options, correctOptionIds, images,
                revision.GetString()!, property.Value.Clone());
        }

        _items = result;
    }

    public Task<ExamAnimationSource?> GetAsync(int number, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(_items.GetValueOrDefault(number));
    }

    public Task<IReadOnlyList<ExamAnimationSource>> GetAllAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult<IReadOnlyList<ExamAnimationSource>>(_items.Values.OrderBy(item => item.Number).ToArray());
    }

    private static string ResolveDirectory(string contentRoot)
    {
        var candidates = new[]
        {
            Path.Combine(contentRoot, "ExamAnimations"),
            Path.GetFullPath(Path.Combine(contentRoot, "..", "content-animations", "bank-review"))
        };
        return candidates.FirstOrDefault(path =>
                   File.Exists(Path.Combine(path, "bank.json")) &&
                   File.Exists(Path.Combine(path, "scenes.json")) &&
                   File.Exists(Path.Combine(path, "accepted-release.json")))
               ?? throw new InvalidOperationException("Không tìm thấy catalog mô phỏng đã duyệt.");
    }
}
