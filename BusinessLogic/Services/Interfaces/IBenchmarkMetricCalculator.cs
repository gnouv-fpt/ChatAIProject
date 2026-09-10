namespace BusinessLogic.Services.Interfaces;

public interface IBenchmarkMetricCalculator
{
    RetrievalMetricScore CalculateRetrieval(
        IReadOnlyList<int> rankedChunkIds,
        IReadOnlyDictionary<int, byte> goldRelevance);

    CitationMetricScore CalculateCitation(
        IReadOnlyCollection<int> citationChunkIds,
        IReadOnlyCollection<int> goldChunkIds);

    decimal? CalculateNoAnswerF1(
        IEnumerable<NoAnswerPrediction> predictions);

    long CalculatePercentile(
        IEnumerable<long> values,
        decimal percentile);
}

public sealed record RetrievalMetricScore(
    decimal RecallAt5,
    decimal MrrAt10,
    decimal NdcgAt5);

public sealed record CitationMetricScore(
    decimal Precision,
    decimal Recall,
    decimal F1);

public sealed record NoAnswerPrediction(
    bool ExpectedNoAnswer,
    bool PredictedNoAnswer);