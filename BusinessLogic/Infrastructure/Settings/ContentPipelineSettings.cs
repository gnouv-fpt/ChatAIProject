namespace BusinessLogic.Infrastructure.Settings;

public sealed class ContentPipelineSettings
{
    // Enable only after K04 deactivation/versioning and V02 SQL eligibility checks are integrated.
    public bool EnableVerifiedIndexing { get; init; }
}
