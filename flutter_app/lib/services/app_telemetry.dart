/// Optional event sink used by the chat flow.
abstract class AppTelemetry {
  Future<void> event(String name, Map<String, Object?> properties);
}
