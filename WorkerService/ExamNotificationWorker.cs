using System.Text;
using System.Text.Json;
using BusinessLogic.Exams;
using Confluent.Kafka;

namespace WorkerService;

public sealed class ExamNotificationWorker(
    IConfiguration config,
    IProducer<string, string> producer,
    RedisNotificationInbox inbox,
    ILogger<ExamNotificationWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var topic = config["Exams:Kafka:Topic"]
            ?? throw new InvalidOperationException("Exams:Kafka:Topic is required.");
        var group = config["Exams:Kafka:GroupId"]
            ?? throw new InvalidOperationException("Exams:Kafka:GroupId is required.");
        var dlq = config["Exams:Kafka:DeadLetterTopic"]
            ?? throw new InvalidOperationException("Exams:Kafka:DeadLetterTopic is required.");
        using var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
        {
            BootstrapServers = config["Exams:Kafka:BootstrapServers"],
            GroupId = group,
            AutoOffsetReset = AutoOffsetReset.Earliest,
            EnableAutoCommit = false,
            EnableAutoOffsetStore = false,
            AllowAutoCreateTopics = false
        }).Build();
        consumer.Subscribe(topic);
        logger.LogInformation("Exam notification worker subscribed to {Topic} as {Group}", topic, group);
        while (!stoppingToken.IsCancellationRequested)
        {
            ConsumeResult<string, string>? message;
            try { message = consumer.Consume(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (ConsumeException ex)
            {
                logger.LogError(ex, "Kafka consume error");
                await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
                continue;
            }
            if (message is null || message.IsPartitionEOF) continue;
            try
            {
                await ProcessWithRetryAsync(message, dlq, stoppingToken);
                consumer.Commit(message);
                logger.LogInformation("Kafka offset committed at {Offset}", message.TopicPartitionOffset);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex)
            {
                logger.LogError(ex, "Kafka processing failed at {TopicPartitionOffset}; offset retained",
                    message.TopicPartitionOffset);
                await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
                consumer.Seek(message.TopicPartitionOffset);
            }
        }
    }

    private async Task ProcessWithRetryAsync(ConsumeResult<string, string> message, string dlq,
        CancellationToken cancellationToken)
    {
        ExamSubmittedEvent? @event;
        try { @event = JsonSerializer.Deserialize<ExamSubmittedEvent>(message.Message.Value); }
        catch (JsonException ex)
        {
            await SendToDlqAsync(message, dlq, ex.Message, cancellationToken);
            return;
        }
        if (@event is null || @event.EventId == Guid.Empty || @event.SchemaVersion != 1 ||
            @event.EntityId != @event.EventId)
        {
            await SendToDlqAsync(message, dlq, "Invalid exam event envelope", cancellationToken);
            return;
        }

        for (var attempt = 1; attempt <= 3; attempt++)
        {
            try
            {
                var added = await inbox.AddAsync(@event, cancellationToken);
                logger.LogInformation("Exam event {EventId} {Status} at {Offset}", @event.EventId,
                    added ? "processed" : "duplicate", message.TopicPartitionOffset);
                return;
            }
            catch (Exception ex) when (ex is not OperationCanceledException && attempt < 3)
            {
                logger.LogWarning(ex, "Exam event {EventId} retry {Attempt}", @event.EventId, attempt);
                await Task.Delay(TimeSpan.FromSeconds(attempt), cancellationToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                await SendToDlqAsync(message, dlq, ex.Message, cancellationToken);
                logger.LogError(ex, "Exam event {EventId} moved to DLQ", @event.EventId);
                return;
            }
        }
    }

    private async Task SendToDlqAsync(ConsumeResult<string, string> original, string dlq,
        string reason, CancellationToken cancellationToken)
    {
        var headers = new Headers
        {
            { "source-topic", Encoding.UTF8.GetBytes(original.Topic) },
            { "source-offset", Encoding.UTF8.GetBytes(original.Offset.Value.ToString()) },
            { "reason", Encoding.UTF8.GetBytes(reason[..Math.Min(reason.Length, 500)]) }
        };
        var ack = await producer.ProduceAsync(dlq, new Message<string, string>
        {
            Key = original.Message.Key,
            Value = original.Message.Value,
            Headers = headers
        }, cancellationToken);
        if (ack.Status != PersistenceStatus.Persisted)
            throw new InvalidOperationException("Kafka did not confirm DLQ delivery.");
    }
}
