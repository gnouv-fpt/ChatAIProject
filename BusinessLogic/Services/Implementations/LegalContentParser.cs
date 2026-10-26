using System.Text.RegularExpressions;
using BusinessLogic.Exceptions;
using HtmlAgilityPack;

namespace BusinessLogic.Services.Implementations;

public sealed record ParsedLegalContent(string Number, string Title, string Content);
public sealed record LegalChunk(string? Article, string? Clause, string Content);

public static class LegalContentParser
{
    public static bool IsAllowedSource(Uri uri) => uri.Scheme == "https" &&
        uri.Host.Equals("thuvienphapluat.vn", StringComparison.OrdinalIgnoreCase) && uri.IsDefaultPort &&
        string.IsNullOrEmpty(uri.UserInfo) && uri.AbsolutePath.StartsWith("/van-ban/", StringComparison.OrdinalIgnoreCase);

    public static ParsedLegalContent Parse(string html)
    {
        var doc = new HtmlDocument();
        doc.LoadHtml(html);
        var title = Clean(doc.DocumentNode.SelectSingleNode("//h1")?.InnerText ?? "");
        var root = doc.DocumentNode.SelectSingleNode("//*[@id='divContentDoc']")
            ?? doc.DocumentNode.SelectSingleNode("//*[contains(concat(' ', normalize-space(@class), ' '), ' content1 ')]");
        if (root is null || string.IsNullOrWhiteSpace(title))
            throw new BadRequestException("Không tìm thấy tiêu đề/nội dung. Cần kiểm tra selector hoặc quyền truy cập nguồn.");
        foreach (var node in root.SelectNodes(".//script|.//style")?.ToList() ?? []) node.Remove();
        var blocks = root.SelectNodes(".//p|.//div[not(div) and not(p)]");
        var content = blocks is null ? Clean(root.InnerText) : string.Join("\n", blocks.Select(n => Clean(n.InnerText)).Where(t => t.Length > 0));
        var text = string.Join(" ", doc.DocumentNode.Descendants("#text").Select(n => Clean(n.InnerText)));
        var number = Regex.Match(text, @"Số\s*:\s*([\p{L}\d][\p{L}\d/._-]{1,99})", RegexOptions.IgnoreCase).Groups[1].Value;
        if (number.Length == 0 || content.Length < 100 || !Regex.IsMatch(content, @"Điều\s+\d+", RegexOptions.IgnoreCase))
            throw new BadRequestException("Nguồn thiếu số hiệu hoặc toàn văn Điều luật; không lưu dữ liệu thay thế.");
        return new(number, title, content);
    }

    public static IReadOnlyList<LegalChunk> Chunk(string content)
    {
        var result = new List<LegalChunk>();
        string? article = null, clause = null;
        var lines = new List<string>();
        void Flush() { if (lines.Count > 0) { result.Add(new(article, clause, string.Join("\n", lines))); lines.Clear(); } }
        foreach (var line in content.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var a = Regex.Match(line, @"^Điều\s+(\d+[a-zđ]?)\s*[.:]", RegexOptions.IgnoreCase);
            var c = Regex.Match(line, @"^(\d+)\.\s");
            if (a.Success) { Flush(); article = a.Groups[1].Value; clause = null; }
            else if (c.Success && article is not null) { Flush(); clause = c.Groups[1].Value; }
            if (lines.Sum(x => x.Length) + line.Length > 6000) Flush();
            for (var offset = 0; offset < line.Length; offset += 6000)
            {
                lines.Add(line.Substring(offset, Math.Min(6000, line.Length - offset)));
                if (offset + 6000 < line.Length) Flush();
            }
        }
        Flush();
        return result.Where(c => c.Article is not null).ToList();
    }
    private static string Clean(string value) => Regex.Replace(HtmlEntity.DeEntitize(value).Replace('\u00a0', ' '), @"\s+", " ").Trim();
}
