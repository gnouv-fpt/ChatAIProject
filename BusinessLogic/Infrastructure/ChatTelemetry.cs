using System.Diagnostics.Metrics;

namespace BusinessLogic.Infrastructure;

public static class ChatTelemetry
{
    private static readonly Meter Meter = new("ChatAIWeb.Chat", "1.0");
    public static readonly Counter<long> Requests = Meter.CreateCounter<long>("chat_turns_total");
    public static readonly Counter<long> Tokens = Meter.CreateCounter<long>("chat_tokens_total");
    public static readonly Histogram<double> Duration = Meter.CreateHistogram<double>("chat_duration_seconds", "s");
}
