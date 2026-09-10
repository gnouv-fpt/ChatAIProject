using BusinessLogic.Services.Interfaces;

namespace BusinessLogic.Services.Implementations;

public sealed class BenchmarkMetricCalculator : IBenchmarkMetricCalculator
{
    public RetrievalMetricScore CalculateRetrieval(
        IReadOnlyList<int> rankedChunkIds,
        IReadOnlyDictionary<int, byte> goldRelevance)
    {
        if (goldRelevance.Count == 0)
        {
            return new RetrievalMetricScore(0, 0, 0);
        }

        var rankedDistinct = rankedChunkIds
            .Distinct()
            .ToList();

        var hitsAt5 = rankedDistinct
            .Take(5)
            .Count(goldRelevance.ContainsKey);
        var recallAt5 = hitsAt5 / (decimal)goldRelevance.Count;

        var firstRelevantRank = rankedDistinct
            .Take(10)
            .Select((chunkId, index) => new { chunkId, rank = index + 1 })
            .FirstOrDefault(item => goldRelevance.ContainsKey(item.chunkId));
        var mrrAt10 = firstRelevantRank is null
            ? 0
            : 1m / firstRelevantRank.rank;

        var dcg = CalculateDcg(
            rankedDistinct
                .Take(5)
                .Select(chunkId => goldRelevance.GetValueOrDefault(chunkId)));
        var idealDcg = CalculateDcg(
            goldRelevance.Values
                .OrderByDescending(grade => grade)
                .Take(5));
        var ndcgAt5 = idealDcg <= 0
            ? 0
            : dcg / idealDcg;

        return new RetrievalMetricScore(
            ClampScore(recallAt5),
            ClampScore(mrrAt10),
            ClampScore(ndcgAt5));
    }

    public CitationMetricScore CalculateCitation(
        IReadOnlyCollection<int> citationChunkIds,
        IReadOnlyCollection<int> goldChunkIds)
    {
        var predicted = citationChunkIds.ToHashSet();
        var gold = goldChunkIds.ToHashSet();
        if (gold.Count == 0)
        {
            return new CitationMetricScore(0, 0, 0);
        }

        var truePositive = predicted.Count(gold.Contains);
        var precision = predicted.Count == 0
            ? 0
            : truePositive / (decimal)predicted.Count;
        var recall = truePositive / (decimal)gold.Count;
        var f1 = precision + recall == 0
            ? 0
            : 2 * precision * recall / (precision + recall);

        return new CitationMetricScore(
            ClampScore(precision),
            ClampScore(recall),
            ClampScore(f1));
    }

    public decimal? CalculateNoAnswerF1(
        IEnumerable<NoAnswerPrediction> predictions)
    {
        var rows = predictions.ToList();
        if (!rows.Any(row => row.ExpectedNoAnswer))
        {
            return null;
        }

        var truePositive = rows.Count(row => row.ExpectedNoAnswer && row.PredictedNoAnswer);
        var falsePositive = rows.Count(row => !row.ExpectedNoAnswer && row.PredictedNoAnswer);
        var falseNegative = rows.Count(row => row.ExpectedNoAnswer && !row.PredictedNoAnswer);
        var denominator = (2 * truePositive) + falsePositive + falseNegative;

        return denominator == 0
            ? 0
            : ClampScore((2m * truePositive) / denominator);
    }

    public long CalculatePercentile(
        IEnumerable<long> values,
        decimal percentile)
    {
        var sorted = values
            .Where(value => value >= 0)
            .OrderBy(value => value)
            .ToList();
        if (sorted.Count == 0)
        {
            return 0;
        }

        var normalizedPercentile = Math.Clamp(percentile, 0, 1);
        var rank = Math.Max(1, (int)Math.Ceiling(normalizedPercentile * sorted.Count));
        return sorted[rank - 1];
    }

    private static decimal CalculateDcg(IEnumerable<byte> relevanceGrades)
    {
        return relevanceGrades
            .Select((grade, index) =>
                (decimal)((Math.Pow(2, grade) - 1) / Math.Log2(index + 2)))
            .Sum();
    }

    private static decimal ClampScore(decimal value)
    {
        return Math.Clamp(value, 0, 1);
    }
}