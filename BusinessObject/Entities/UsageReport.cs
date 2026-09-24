namespace BusinessObject.Entities;

public class UsageReport
{
    public Guid Id { get; set; }

    public DateOnly ReportDate { get; set; }

    public int TotalQueries { get; set; }

    public long TotalTokensUsed { get; set; }

    public int TotalViolations { get; set; }

    public DateTime CreatedAt { get; set; }
}
