namespace BusinessLogic.Infrastructure.Interfaces;

public interface IEventPublisher
{
    Task PublishAsync<T>(string topicOrChannel, T @event, CancellationToken cancellationToken = default);
}
