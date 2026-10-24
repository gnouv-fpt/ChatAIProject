using System.Text.Json;

namespace Presentation.Infrastructure;

// File telemetry deliberately omits formatted application messages, exception details and scopes.
// It cannot accidentally serialize prompts, tokens, SQL parameter values or image data.
public sealed class SafeFileLoggerProvider(string path) : ILoggerProvider
{
    private readonly string filePath = path;
    private readonly object gate = new();
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
                    if (field.Key is "MessageId" or "RequestId" or "ResultStatus" or "TokensUsed" or "Status" or "ExceptionType")
                        fields[field.Key] = field.Value;
            var line = JsonSerializer.Serialize(new
            {
                timestamp = DateTime.UtcNow, level = level.ToString(), category,
                eventId = eventId.Id, exceptionType = exception?.GetType().Name,
                traceId = System.Diagnostics.Activity.Current?.TraceId.ToString(),
                spanId = System.Diagnostics.Activity.Current?.SpanId.ToString(), fields
            });
            lock (owner.gate)
            {
                var fullPath = Path.GetFullPath(owner.filePath);
                Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
                // Daily files avoid an unbounded single file; Alloy tails the glob.
                var daily = Path.Combine(Path.GetDirectoryName(fullPath)!, Path.GetFileNameWithoutExtension(fullPath) + "-" + DateTime.UtcNow.ToString("yyyyMMdd") + ".jsonl");
                try { File.AppendAllText(daily, line + Environment.NewLine); }
                catch (IOException) { /* Logging failure must not change a committed API result. */ }
                catch (UnauthorizedAccessException) { }
            }
        }
    }
}
