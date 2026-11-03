using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace BusinessLogic.Exams;

public static class ExamEventTelemetry
{
    public const string Name = "ChatAIWeb.ExamEvents";
    public static readonly ActivitySource Activities = new(Name);
    private static readonly Meter Meter = new(Name, "1.0");
    public static readonly Counter<long> BrokerConfirmed = Meter.CreateCounter<long>("exam_event_broker_confirmed_total");
    public static readonly Counter<long> Received = Meter.CreateCounter<long>("exam_event_received_total");
    public static readonly Counter<long> Processed = Meter.CreateCounter<long>("exam_event_processed_total");
    public static readonly Counter<long> Duplicate = Meter.CreateCounter<long>("exam_event_duplicate_total");
    public static readonly Counter<long> Retry = Meter.CreateCounter<long>("exam_event_retry_total");
    public static readonly Counter<long> Failed = Meter.CreateCounter<long>("exam_event_failed_total");
}
