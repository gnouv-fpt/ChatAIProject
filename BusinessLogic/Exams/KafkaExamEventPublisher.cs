using System.Text.Json;
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
        var delivery = await producer.ProduceAsync(topic, new Message<string, string>
        {
            Key = @event.UserId.ToString("N"),
            Value = JsonSerializer.Serialize(@event)
        }, cancellationToken);
        if (delivery.Status != PersistenceStatus.Persisted)
            throw new InvalidOperationException("Kafka did not confirm durable event delivery.");
    }
}
