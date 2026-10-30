using BusinessLogic.DTOs;

namespace BusinessLogic.Services.Interfaces;

public interface IContentManifestService
{
    ContentManifestPreviewDto Preview(ContentManifestRequestDto request);
    ContentCapabilitiesDto GetCapabilities();
}
