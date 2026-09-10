namespace BusinessLogic.Services.Interfaces;

public interface IRagasEvaluatorClient
{
    Task<IReadOnlyList<RagasEvaluationScore>> EvaluateAsync(
        IReadOnlyList<RagasEvaluationSample> samples,
        CancellationToken cancellationToken = default);
}

public sealed record RagasEvaluationSample(
    string Question,
    string GroundTruthAnswer,
    string GeneratedAnswer,
    IReadOnlyList<string> RetrievedContexts);

public sealed record RagasEvaluationScore(
    decimal AnswerCorrectness,
    decimal Faithfulness);