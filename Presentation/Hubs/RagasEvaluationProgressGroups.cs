using System.Text.RegularExpressions;

namespace Presentation.Hubs;

public static partial class RagasEvaluationProgressGroups
{
    public static string ForUserEvaluation(int userId, string evaluationId)
    {
        return $"ragas:{userId}:{evaluationId.ToLowerInvariant()}";
    }

    public static bool IsValidEvaluationId(string? evaluationId)
    {
        return !string.IsNullOrWhiteSpace(evaluationId)
            && EvaluationIdPattern().IsMatch(evaluationId);
    }

    [GeneratedRegex("^[a-fA-F0-9]{32}$", RegexOptions.CultureInvariant)]
    private static partial Regex EvaluationIdPattern();
}
