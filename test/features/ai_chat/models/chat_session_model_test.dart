import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
      // explicitToJson on the model deep-serializes messages, so the
      // roundtrip works without any test-side adaptation.
      final back = ChatSession.fromJson(s.toJson());
      expect(back.id, 'sid');
      expect(back.title, 'T');
      expect(back.categoryId, 'cat');
      expect(back.messages.length, 1);
      expect(back.metadata?['foo'], 'bar');
    });

    test('copyWith replaces messages while preserving identity fields', () {
      final base = ChatSession(
        id: 'sid',
        title: 'T',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024, 1, 2),
        messages: const [],
        categoryId: 'cat',
      );

      final next = base.copyWith(
        messages: [ChatMessage.user('hello')],
        lastMessageAt: DateTime(2024, 1, 3),
      );

      expect(next.messages, hasLength(1));
      expect(next.lastMessageAt, DateTime(2024, 1, 3));
      expect(next.id, base.id);
      expect(next.title, base.title);
      expect(next.categoryId, base.categoryId);
      expect(next.createdAt, base.createdAt);
    });

    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      glados.IntAnys(glados.any).intInRange(0, 6),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'fromJson(toJson(s)) == s for sessions with 0..5 messages',
      (seed, messageCount) {
        final session = ChatSession(
          id: 'sid-$seed',
          title: 'Session $seed',
          createdAt: DateTime.fromMillisecondsSinceEpoch(seed * 1000),
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(seed * 2000),
          messages: [
            for (var i = 0; i < messageCount; i++)
              ChatMessage(
                id: 'm-$seed-$i',
                content: 'msg $i of $seed',
                role: ChatMessageRole.values[(seed + i) % 3],
                timestamp: DateTime.fromMillisecondsSinceEpoch(i * 500),
              ),
          ],
          categoryId: seed.isEven ? 'cat-$seed' : null,
          metadata: seed % 3 == 0 ? null : {'k': seed},
        );

        // Message order and content must survive the deep roundtrip.
        expect(ChatSession.fromJson(session.toJson()), session);
      },
      tags: 'glados',
    );
  });
}
