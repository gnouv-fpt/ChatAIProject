namespace BusinessObject.Entities;

public sealed record CrawlJob(Guid Id, string Status, DateTime StartedAt, DateTime? FinishedAt, string InstanceId);
