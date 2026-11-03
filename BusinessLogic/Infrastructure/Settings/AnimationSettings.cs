namespace BusinessLogic.Infrastructure.Settings;

public sealed class AnimationSettings
{
    // Exact host names, configured by the server, never accepted from an import request.
    public string[] AllowedHosts { get; init; } = [];

    // Bound by the host only in Development; never enabled by a bank import.
    public string? LocalAssetOrigin { get; init; }

    public static bool IsLocalAssetUrl(string? value, string? origin)
    {
        if (!Uri.TryCreate(origin, UriKind.Absolute, out var root) || root.Scheme != "http" ||
            !root.IsLoopback || root.AbsolutePath != "/" || root.Query.Length != 0 || root.Fragment.Length != 0 ||
            root.UserInfo.Length != 0 || !Uri.TryCreate(value, UriKind.Absolute, out var uri) ||
            uri.GetLeftPart(UriPartial.Authority) != root.GetLeftPart(UriPartial.Authority) ||
            uri.UserInfo.Length != 0 || uri.Query.Length != 0 || uri.Fragment.Length != 0 ||
            value!.Any(char.IsWhiteSpace) || value.Contains('\\')) return false;
        var decoded = Uri.UnescapeDataString(value);
        return !decoded.Any(char.IsControl) && !decoded.Contains('%') && !decoded.Contains('\\') &&
            !decoded.Split('/').Any(segment => segment is "." or "..");
    }
}
