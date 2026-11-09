import '../features/chat/models/chat_session.dart';

/// Optional persistence contract for chat history.
abstract class ActivityRepository {
  Future<List<ChatSession>> loadSessions();
  Future<void> saveSession(ChatSession session);
  Future<void> deleteSession(String sessionId);
}
