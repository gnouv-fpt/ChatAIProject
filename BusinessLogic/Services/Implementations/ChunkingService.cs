using BusinessLogic.DTOs.Requests;
using BusinessLogic.Infrastructure;
using BusinessLogic.Infrastructure.Interfaces;
using BusinessLogic.Services.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class ChunkingService : IChunkingService
{
    private static readonly char[] WhitespaceCharacters = [' ', '\r', '\n', '\t'];

    private readonly ISystemSettingsService _settingsService;

    public ChunkingService(ISystemSettingsService settingsService)
    {
        _settingsService = settingsService;
    }

    public async Task<IReadOnlyList<DocumentChunkDraft>> SplitIntoChunksAsync(
        IReadOnlyList<ExtractedTextSegment> segments,
        CancellationToken cancellationToken = default)
    {
        var settings = await _settingsService.GetSettingsAsync(cancellationToken);
        var chunks = new List<DocumentChunkDraft>();
        var cleanSegments = segments
            .Where(segment => !string.IsNullOrWhiteSpace(segment.Text))
            .ToList();

        switch (NormalizeMode(settings.ChunkSizeMode))
        {
            case "Page":
                SplitByPage(cleanSegments, settings, chunks);
                break;
            case "Character":
                SplitSegmentsByCharacters(cleanSegments, settings, chunks);
                break;
            default:
                SplitSegmentsByWords(cleanSegments, settings, chunks);
                break;
        }

        return chunks;
    }

    private static void SplitByPage(
        IReadOnlyList<ExtractedTextSegment> segments,
        SystemSettingsDto settings,
        List<DocumentChunkDraft> chunks)
    {
        var pageChunkSize = Math.Clamp(settings.PageChunkSize, 1, 20);
        var pageBuffer = new List<ExtractedTextSegment>();

        foreach (var segment in segments)
        {
            if (!HasPageOrSlide(segment))
            {
                FlushPageBuffer(pageBuffer, settings, chunks);
                SplitSegmentByWords(segment, settings, chunks);
                continue;
            }

            pageBuffer.Add(segment);
            if (pageBuffer.Count >= pageChunkSize)
            {
                FlushPageBuffer(pageBuffer, settings, chunks);
            }
        }

        FlushPageBuffer(pageBuffer, settings, chunks);
    }

    private static void FlushPageBuffer(
        List<ExtractedTextSegment> pageBuffer,
        SystemSettingsDto settings,
        List<DocumentChunkDraft> chunks)
    {
        if (pageBuffer.Count == 0)
        {
            return;
        }

        var first = pageBuffer[0];
        AddOrMergeChunk(
            chunks,
            string.Join(Environment.NewLine + Environment.NewLine, pageBuffer.Select(segment => segment.Text)),
            first.PageNumber,
            first.SlideNumber,
            settings.MinChunkCharacters);
        pageBuffer.Clear();
    }

    private static void SplitSegmentsByWords(
        IReadOnlyList<ExtractedTextSegment> segments,
        SystemSettingsDto settings,
        List<DocumentChunkDraft> chunks)
    {
        foreach (var segment in segments)
        {
            SplitSegmentByWords(segment, settings, chunks);
        }
    }

    private static void SplitSegmentByWords(
        ExtractedTextSegment segment,
        SystemSettingsDto settings,
        List<DocumentChunkDraft> chunks)
    {
        foreach (var content in SplitTextByWords(
                     segment.Text,
                     Math.Clamp(settings.WordChunkSize, 50, 3000),
                     Math.Clamp(settings.ChunkOverlapSize, 0, 2000)))
        {
            AddOrMergeChunk(chunks, content, segment.PageNumber, segment.SlideNumber, settings.MinChunkCharacters);
        }
    }

    private static void SplitSegmentsByCharacters(
        IReadOnlyList<ExtractedTextSegment> segments,
        SystemSettingsDto settings,
        List<DocumentChunkDraft> chunks)
    {
        foreach (var segment in segments)
        {
            foreach (var content in SplitTextByCharacters(
                         segment.Text,
                         Math.Clamp(settings.CharacterChunkSize, 200, 20000),
                         Math.Clamp(settings.ChunkOverlapSize, 0, 2000)))
            {
                AddOrMergeChunk(chunks, content, segment.PageNumber, segment.SlideNumber, settings.MinChunkCharacters);
            }
        }
    }

    private static IEnumerable<string> SplitTextByWords(string text, int chunkSize, int overlapSize)
    {
        var words = text.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (words.Length == 0)
        {
            yield break;
        }

        var safeOverlap = Math.Min(Math.Max(overlapSize, 0), chunkSize - 1);
        var step = Math.Max(1, chunkSize - safeOverlap);

        for (var start = 0; start < words.Length; start += step)
        {
            var count = Math.Min(chunkSize, words.Length - start);
            yield return string.Join(' ', words.Skip(start).Take(count));

            if (start + count >= words.Length)
            {
                yield break;
            }
        }
    }

    private static IEnumerable<string> SplitTextByCharacters(string text, int chunkSize, int overlapSize)
    {
        var cleanedText = text.Trim();
        if (cleanedText.Length == 0)
        {
            yield break;
        }

        var safeOverlap = Math.Min(Math.Max(overlapSize, 0), chunkSize - 1);
        var index = 0;

        while (index < cleanedText.Length)
        {
            var maxEnd = Math.Min(index + chunkSize, cleanedText.Length);
            var end = FindCharacterChunkEnd(cleanedText, index, maxEnd, chunkSize);
            var chunk = cleanedText[index..end].Trim();
            if (!string.IsNullOrWhiteSpace(chunk))
            {
                yield return chunk;
            }

            if (end >= cleanedText.Length)
            {
                yield break;
            }

            var nextIndex = end - safeOverlap;
            index = nextIndex <= index ? end : nextIndex;
        }
    }

    private static int FindCharacterChunkEnd(string text, int start, int maxEnd, int chunkSize)
    {
        if (maxEnd >= text.Length)
        {
            return text.Length;
        }

        var minUsefulEnd = start + Math.Max(1, chunkSize / 2);
        for (var index = maxEnd - 1; index > minUsefulEnd; index--)
        {
            if (WhitespaceCharacters.Contains(text[index]))
            {
                return index;
            }
        }

        return maxEnd;
    }

    private static void AddOrMergeChunk(
        List<DocumentChunkDraft> chunks,
        string content,
        int? pageNumber,
        int? slideNumber,
        int minChunkCharacters)
    {
        var cleanedContent = NormalizeChunkContent(content);
        if (string.IsNullOrWhiteSpace(cleanedContent))
        {
            return;
        }

        var safeMinCharacters = Math.Clamp(minChunkCharacters, 1, 1000);
        if (cleanedContent.Length < safeMinCharacters && chunks.Count > 0)
        {
            var previous = chunks[^1];
            if (previous.PageNumber == pageNumber && previous.SlideNumber == slideNumber)
            {
                var mergedContent = NormalizeChunkContent($"{previous.Content}{Environment.NewLine}{Environment.NewLine}{cleanedContent}");
                chunks[^1] = previous with
                {
                    Content = mergedContent,
                    TokenCount = CountApproximateTokens(mergedContent)
                };
                return;
            }
        }

        chunks.Add(new DocumentChunkDraft(
            chunks.Count,
            cleanedContent,
            pageNumber,
            slideNumber,
            CountApproximateTokens(cleanedContent)));
    }

    private static bool HasPageOrSlide(ExtractedTextSegment segment)
    {
        return segment.PageNumber.HasValue || segment.SlideNumber.HasValue;
    }

    private static string NormalizeMode(string? mode)
    {
        return string.Equals(mode, "Page", StringComparison.OrdinalIgnoreCase)
            ? "Page"
            : string.Equals(mode, "Character", StringComparison.OrdinalIgnoreCase)
                ? "Character"
                : "Word";
    }

    private static string NormalizeChunkContent(string content)
    {
        return string.Join(Environment.NewLine, content
            .Split(['\r', '\n'], StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries))
            .Trim();
    }

    private static int CountApproximateTokens(string text)
    {
        return text.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Length;
    }
}
