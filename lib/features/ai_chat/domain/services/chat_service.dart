import 'package:lotti/features/ai_chat/domain/models/task_query.dart';
import 'package:lotti/features/ai_chat/domain/models/task_summary.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';

abstract class ChatService {
  Stream<String> processMessage({
    required String userMessage,
    required List<ChatMessage> conversationHistory,
    String? categoryId,
    bool enableThinking = false,
  });

  Future<TaskSummaryResult> executeTaskQuery(TaskQuery query);

  Future<String> generateSystemPrompt({
    String? categoryId,
    bool enableThinking = false,
  });

  Future<bool> shouldUseTaskQuery(String message);

  Future<TaskQuery?> parseTaskQuery(String message);
}
