using System.Security.Cryptography;
using System.Text.Json;
using BusinessLogic.DTOs;
using BusinessLogic.Infrastructure.Settings;
using BusinessLogic.Services.Interfaces;

namespace BusinessLogic.Services.Implementations;

// Pure preflight; no database, filesystem mutation, network fetch or publication.
public sealed class ContentManifestService(AnimationSettings settings) : IContentManifestService
{
    public ContentCapabilitiesDto GetCapabilities() => new(true, true, false, "PendingSqlContract", settings.AllowedHosts);

    public ContentManifestPreviewDto Preview(ContentManifestRequestDto request)
    {
        var issues = new List<ContentValidationIssueDto>();
        if (request.Bank is null)
            return new(null, 0, 0, [new("bank", "Thiếu ngân hàng câu hỏi.")]);
        issues.AddRange(QuestionBankService.Validate(request.Bank).Select(message => new ContentValidationIssueDto("bank", message)));
        var questions = request.Bank.Questions;
        var ids = questions?.Where(q => q is not null).Select(q => q.Id).ToHashSet() ?? [];
        var animations = request.Animations;
        if (animations is null)
            issues.Add(new("animations", "Danh sách animation không được null."));
        else
        {
            if (animations.Count > 5000) issues.Add(new("animations", "Tối đa 5000 liên kết animation."));
            var seen = new HashSet<Guid>();
            for (var index = 0; index < animations.Count; index++)
            {
                var animation = animations[index];
                var path = $"animations[{index}]";
                if (animation is null) { issues.Add(new(path, "Animation không được null.")); continue; }
                if (!ids.Contains(animation.QuestionId)) issues.Add(new(path + ".questionId", "Animation phải tham chiếu câu trong cùng bank/version."));
                if (!seen.Add(animation.QuestionId)) issues.Add(new(path + ".questionId", "Mỗi câu chỉ có một ExplanationAnimationUrl."));
                if (!IsAllowedAnimationUrl(animation.ExplanationAnimationUrl, settings.AllowedHosts))
                    issues.Add(new(path + ".explanationAnimationUrl", "Animation cần URL HTTPS trên host được cấu hình, không chứa credentials/query/fragment hoặc đường dẫn bất thường."));
            }
        }
        // Include source/profile/keys/assets/animations in the reviewed hash. Order of questions/options is meaningful.
        var hash = issues.Count == 0 ? Convert.ToHexString(SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(request))) : null;
        return new(hash, questions?.Count ?? 0, animations?.Count ?? 0, issues);
    }

    public static bool IsAllowedAnimationUrl(string? value, IEnumerable<string> allowedHosts)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 2048 || value.Any(char.IsWhiteSpace) || value.Contains('\\') ||
            !Uri.TryCreate(value, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps ||
            !uri.IsDefaultPort || !string.IsNullOrEmpty(uri.UserInfo) || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment) ||
            uri.HostNameType != UriHostNameType.Dns || !allowedHosts.Contains(uri.IdnHost, StringComparer.OrdinalIgnoreCase)) return false;
        var unescaped = Uri.UnescapeDataString(value);
        if (unescaped.Any(char.IsControl) || unescaped.Contains('\\') || unescaped.Contains('%') ||
            unescaped.Split('/').Any(segment => segment is "." or "..")) return false;
        return uri.AbsolutePath.EndsWith(".html", StringComparison.OrdinalIgnoreCase) || uri.AbsolutePath.EndsWith('/');
    }
}
