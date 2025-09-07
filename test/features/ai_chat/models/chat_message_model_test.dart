import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('factory constructors set roles and defaults', () {
      final u = ChatMessage.user('hi');
      final a = ChatMessage.assistant('ok');
      final s = ChatMessage.system('sys');

      expect(u.role, ChatMessageRole.user);
      expect(a.role, ChatMessageRole.assistant);
      expect(s.role, ChatMessageRole.system);
      expect(u.isStreaming, isFalse);
      expect(a.isStreaming, isFalse);
      expect(u.timestamp, isNotNull);
      expect(a.timestamp, isNotNull);
      expect(s.timestamp, isNotNull);
    });

    test('json roundtrip preserves fields', () {
      final m = ChatMessage(
        id: 'id1',
        content: 'content',
        role: ChatMessageRole.user,
        timestamp: DateTime(2024, 1, 2, 3),
        metadata: const {'k': 'v'},
      );
      final json = m.toJson();
      final back = ChatMessage.fromJson(json);
      expect(back.id, 'id1');
      expect(back.content, 'content');
      expect(back.role, ChatMessageRole.user);
      expect(back.metadata?['k'], 'v');
    });
  });
}
