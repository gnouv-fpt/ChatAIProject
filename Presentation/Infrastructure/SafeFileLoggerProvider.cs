using System.Text.Json;

namespace Presentation.Infrastructure;

// File telemetry deliberately omits formatted application messages, exception details and scopes.
// It cannot accidentally serialize prompts, tokens, SQL parameter values or image data.
public sealed class SafeFileLoggerProvider(string path, long maxBytes = 10 * 1024 * 1024, int retentionDays = 7) : ILoggerProvider
{
    private readonly string filePath = path;
    private readonly object gate = new();
    private DateOnly lastCleanup;
    private readonly long fileLimit = Math.Max(1024, maxBytes);
    private readonly int daysToKeep = Math.Max(1, retentionDays);
    public ILogger CreateLogger(string categoryName) => new SafeLogger(this, categoryName);
    public void Dispose() { }
    private sealed class SafeLogger(SafeFileLoggerProvider owner, string category) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel level) => level >= LogLevel.Information;
        public void Log<TState>(LogLevel level, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(level)) return;
            var fields = new Dictionary<string, object?>();
            if (state is IEnumerable<KeyValuePair<string, object?>> values)
                foreach (var field in values)
                    if (field.Key is "MessageId" or "RequestId" or "ResultStatus" or "TokensUsed" or "Status" or "ExceptionType"
                        or "Operation" or "DurationMs" or "Method" or "Route" or "EventId" or "Topic" or "ConsumerGroup" or "Partition" or "Offset" or "Attempt")
                        fields[field.Key] = field.Value;
            var line = JsonSerializer.Serialize(new
            {
                timestamp = DateTime.UtcNow, service = Path.GetFileNameWithoutExtension(owner.filePath),
                level = level.ToString(), category,
                eventId = eventId.Id, exceptionType = exception?.GetType().Name,
                traceId = System.Diagnostics.Activity.Current?.TraceId.ToString(),
                spanId = System.Diagnostics.Activity.Current?.SpanId.ToString(), fields
            });
            lock (owner.gate)
            {
                var fullPath = Path.GetFullPath(owner.filePath);
                Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
                var today = DateOnly.FromDateTime(DateTime.UtcNow);
                var stem = Path.GetFileNameWithoutExtension(fullPath);
                var daily = Path.Combine(Path.GetDirectoryName(fullPath)!, stem + "-" + today.ToString("yyyyMMdd") + ".jsonl");
                try
                {
                    if (owner.lastCleanup != today)
                    {
                        owner.lastCleanup = today;
                        foreach (var old in Directory.EnumerateFiles(Path.GetDirectoryName(fullPath)!, stem + "-*.jsonl"))
                            if (File.GetLastWriteTimeUtc(old) < DateTime.UtcNow.AddDays(-owner.daysToKeep)) File.Delete(old);
                    }
                    if (File.Exists(daily) && new FileInfo(daily).Length + line.Length + 2 > owner.fileLimit)
                    {
                        var slot = 1;
                        string rotated;
                        do { rotated = Path.Combine(Path.GetDirectoryName(fullPath)!, stem + "-" + today.ToString("yyyyMMdd") + "-" + slot++ + ".jsonl"); }
                        while (File.Exists(rotated));
                        if (slot > 11) return; // Bound each service to 10 archives plus the active file per day.
                        File.Move(daily, rotated);
                    }
                    File.AppendAllText(daily, line + Environment.NewLine);
                }
                catch (IOException) { /* Logging failure must not change a committed API result. */ }
                catch (UnauthorizedAccessException) { }
            }
        }
    }
}
