import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

    test('copyWith(isStreaming: true) flips only the streaming flag', () {
      final base = ChatMessage(
        id: 'id1',
        content: 'content',
        role: ChatMessageRole.assistant,
        timestamp: DateTime(2024, 1, 2, 3),
        metadata: const {'k': 'v'},
      );

      final streaming = base.copyWith(isStreaming: true);

      expect(streaming.isStreaming, isTrue);
      expect(streaming.id, base.id);
      expect(streaming.content, base.content);
      expect(streaming.role, base.role);
      expect(streaming.timestamp, base.timestamp);
      expect(streaming.metadata, base.metadata);
      // And back again.
      expect(streaming.copyWith(isStreaming: false), base);
    });

    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 16),
      glados.IntAnys(glados.any).intInRange(0, 3),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'fromJson(toJson(m)) == m for all roles and arbitrary metadata',
      (seed, roleIndex) {
        final message = ChatMessage(
          id: 'id-$seed',
          content: 'content-$seed \n with “unicode” 😀',
          role: ChatMessageRole.values[roleIndex % 3],
          timestamp: DateTime.fromMillisecondsSinceEpoch(seed * 1000),
          isStreaming: seed.isEven,
          metadata: seed % 3 == 0
              ? null
              : {
                  'k$seed': 'v$seed',
                  'n': seed,
                  'nested': {'a': seed},
                },
        );

        expect(ChatMessage.fromJson(message.toJson()), message);
      },
      tags: 'glados',
    );
  });
}
