using System.Reflection;
using Microsoft.AspNetCore.Mvc.ApplicationParts;
using Microsoft.AspNetCore.Mvc.Controllers;

namespace Presentation.Infrastructure;

[AttributeUsage(AttributeTargets.Class)]
public sealed class ServiceModuleAttribute(string module) : Attribute
{
    public string Module { get; } = module;
}

// One binary, two isolated hosts. Unknown controllers default to User; Content controllers opt in.
public sealed class ServiceModuleFeatureProvider(string module) : IApplicationFeatureProvider<ControllerFeature>
{
    public void PopulateFeature(IEnumerable<ApplicationPart> parts, ControllerFeature feature)
    {
        foreach (var controller in feature.Controllers.ToArray())
            if ((controller.GetCustomAttribute<ServiceModuleAttribute>()?.Module ?? "User") != module)
                feature.Controllers.Remove(controller);
    }
}
