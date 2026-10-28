namespace BusinessLogic.Infrastructure.Settings;

public sealed class AnimationSettings
{
    // Exact host names, configured by the server, never accepted from an import request.
    public string[] AllowedHosts { get; init; } = [];
}
