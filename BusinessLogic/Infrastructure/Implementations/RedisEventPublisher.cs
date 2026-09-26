using System.Text.Json;
using BusinessLogic.Infrastructure.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace BusinessLogic.Infrastructure.Implementations;

public class RedisEventPublisher : IEventPublisher
{
    private readonly ILogger<RedisEventPublisher> _logger;
    private readonly string? _connectionString;
    private readonly Lazy<ConnectionMultiplexer?> _lazyConnection;

    public RedisEventPublisher(IConfiguration configuration, ILogger<RedisEventPublisher> logger)
    {
        _logger = logger;
        _connectionString = configuration.GetConnectionString("Redis")
            ?? configuration["Redis:ConnectionString"];

        _lazyConnection = new Lazy<ConnectionMultiplexer?>(() =>
        {
            if (string.IsNullOrWhiteSpace(_connectionString))
            {
                _logger.LogWarning("Redis connection string is not configured. Event publishing will be simulated in logs.");
                return null;
            }

            try
            {
                var options = ConfigurationOptions.Parse(_connectionString);
                options.AbortOnConnectFail = false;
                options.ConnectTimeout = 3000;
                return ConnectionMultiplexer.Connect(options);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to connect to Redis at {ConnectionString}. Events will not be published.", _connectionString);
                return null;
            }
        });
    }

    public async Task PublishAsync<T>(string topicOrChannel, T @event, CancellationToken cancellationToken = default)
    {
        var payload = JsonSerializer.Serialize(@event);
        try
        {
            var connection = _lazyConnection.Value;
            if (connection != null && connection.IsConnected)
            {
                var subscriber = connection.GetSubscriber();
                await subscriber.PublishAsync(RedisChannel.Literal(topicOrChannel), payload);
                _logger.LogInformation("Published event {EventType} to Redis channel {Channel}", typeof(T).Name, topicOrChannel);
            }
            else
            {
                _logger.LogWarning("Redis is not connected. Simulating event publish to channel {Channel}: {Payload}", topicOrChannel, payload);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error publishing event to Redis channel {Channel}", topicOrChannel);
        }
    }
}
