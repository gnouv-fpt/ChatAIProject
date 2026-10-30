using Xunit;

namespace ChatAIWeb.Tests.AccountLearning;

// The API tests configure the host through process environment variables, so this module's tests run serially.
[CollectionDefinition(Name)]
public sealed class AccountLearningCollection
{
    public const string Name = "AccountLearning";
}
