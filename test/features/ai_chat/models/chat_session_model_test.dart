import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';

void main() {
  group('ChatSession', () {
    test('create sets sensible defaults', () {
      final s = ChatSession.create(categoryId: 'cat');
      expect(s.id, isNotEmpty);
      expect(s.title, 'New Chat');
      expect(s.categoryId, 'cat');
      expect(s.messages, isEmpty);
      expect(s.createdAt, isNotNull);
      expect(s.lastMessageAt, isNotNull);
    });

    test('json roundtrip with nested messages and metadata', () {
      final s = ChatSession(
        id: 'sid',
        title: 'T',
        createdAt: DateTime.parse('2024-01-01T00:00:00.000'),
        lastMessageAt: DateTime.parse('2024-01-02T00:00:00.000'),
        messages: [ChatMessage.user('hi')],
        categoryId: 'cat',
        metadata: const {'foo': 'bar'},
      );
      // ChatSession.toJson() doesn't deep-serialize messages; adapt for roundtrip
      final json = s.toJson();
      json['messages'] = s.messages.map((m) => m.toJson()).toList();
      final back = ChatSession.fromJson(Map<String, dynamic>.from(json));
      expect(back.id, 'sid');
      expect(back.title, 'T');
      expect(back.categoryId, 'cat');
      expect(back.messages.length, 1);
      expect(back.metadata?['foo'], 'bar');
    });
  });
}
