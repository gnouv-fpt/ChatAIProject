using System.Text.Json;
using System.Diagnostics;
using BusinessLogic.Exams;
using Confluent.Kafka;
using Microsoft.Extensions.Configuration;

namespace BusinessLogic.Exams;

public sealed class KafkaExamEventPublisher(IProducer<string, string> producer, IConfiguration config)
    : IExamEventPublisher
{
    public async Task PublishAsync(ExamSubmittedEvent @event, CancellationToken cancellationToken)
    {
        var topic = config["Exams:Kafka:Topic"]
            ?? throw new InvalidOperationException("Exams:Kafka:Topic is required.");
        using var activity = ExamEventTelemetry.Activities.StartActivity("kafka publish", ActivityKind.Producer);
        var envelope = @event with { TraceParent = activity?.Id ?? @event.TraceParent };
        var delivery = await producer.ProduceAsync(topic, new Message<string, string>
        {
            Key = @event.UserId.ToString("N"),
            Value = JsonSerializer.Serialize(envelope)
        }, cancellationToken);
        if (delivery.Status != PersistenceStatus.Persisted)
            throw new InvalidOperationException("Kafka did not confirm durable event delivery.");
        ExamEventTelemetry.BrokerConfirmed.Add(1, new KeyValuePair<string, object?>("topic", topic));
        activity?.SetTag("messaging.system", "kafka");
        activity?.SetTag("messaging.destination.name", topic);
        activity?.SetTag("messaging.kafka.partition", delivery.Partition.Value);
        activity?.SetTag("messaging.kafka.offset", delivery.Offset.Value);
    }
}
