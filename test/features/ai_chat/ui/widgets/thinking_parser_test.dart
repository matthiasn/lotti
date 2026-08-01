import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';

void main() {
  group('splitThinkingSegments', () {
    test('returns no segments for empty content', () {
      expect(splitThinkingSegments(''), isEmpty);
    });

    test('preserves plain visible content exactly', () {
      const content = 'plain visible text';

      final segments = splitThinkingSegments(content);

      expect(segments, hasLength(1));
      expect(segments.single.isThinking, isFalse);
      expect(segments.single.text, content);
    });

    test('preserves ordered HTML thinking and visible segments', () {
      final segments = splitThinkingSegments(
        'before<think>first</think>middle'
        '<thinking>second</thinking>after',
      );

      expect(
        segments.map((segment) => segment.isThinking),
        [false, true, false, true, false],
      );
      expect(
        segments.map((segment) => segment.text),
        ['before', 'first', 'middle', 'second', 'after'],
      );
    });

    test('supports bracket markers case-insensitively', () {
      final segments = splitThinkingSegments(
        'a[ThInK]first[/THINK]b[THINKING]second[/thinking]c',
      );

      expect(
        segments.map((segment) => segment.isThinking),
        [false, true, false, true, false],
      );
      expect(
        segments.map((segment) => segment.text),
        ['a', 'first', 'b', 'second', 'c'],
      );
    });

    test('supports think and thinking fenced blocks', () {
      final segments = splitThinkingSegments(
        'pre```think\nfirst\n```mid```thinking\nsecond\n```post',
      );

      expect(
        segments.map((segment) => segment.isThinking),
        [false, true, false, true, false],
      );
      expect(segments[1].text.trim(), 'first');
      expect(segments[3].text.trim(), 'second');
    });

    test('treats open HTML, bracket, and fence blocks as thinking', () {
      for (final (content, expected) in [
        ('before<think>streaming', 'streaming'),
        ('before[thinking]streaming', 'streaming'),
        ('before```think\nstreaming', 'streaming'),
      ]) {
        final segments = splitThinkingSegments(content);

        expect(segments, hasLength(2), reason: content);
        expect(segments.first.text, 'before', reason: content);
        expect(segments.last.isThinking, isTrue, reason: content);
        expect(segments.last.text.trim(), expected, reason: content);
      }
    });

    test('keeps nested markers inside their outer thinking segment', () {
      final segments = splitThinkingSegments(
        'before<think>outer<think>inner</think>end</think>after',
      );

      expect(segments, hasLength(3));
      expect(segments[1].isThinking, isTrue);
      expect(segments[1].text, 'outer<think>inner</think>end');
    });

    test('ignores malformed fence openings and stray closing markers', () {
      for (final content in [
        'pre```think without newline```post',
        'hello </think> world',
        'hello [/thinking] world',
      ]) {
        final segments = splitThinkingSegments(content);

        expect(segments, hasLength(1), reason: content);
        expect(segments.single.isThinking, isFalse, reason: content);
        expect(segments.single.text, content, reason: content);
      }
    });

    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 180),
    ).test('plain generated content round-trips without throwing', (content) {
      final segments = splitThinkingSegments(content);

      if (content.isEmpty) {
        expect(segments, isEmpty);
      } else {
        expect(segments, hasLength(1));
        expect(segments.single.isThinking, isFalse);
        expect(segments.single.text, content);
      }
    }, tags: 'glados');

    glados.Glados2<String, String>(
      glados.any.letterOrDigits,
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test('generated bracket blocks preserve body and tail', (body, tail) {
      final segments = splitThinkingSegments('[think]$body[/think]$tail');
      final thinking = segments.where((segment) => segment.isThinking);

      expect(thinking, hasLength(1));
      expect(thinking.single.text, body);
      if (tail.isNotEmpty) {
        expect(segments.last.isThinking, isFalse);
        expect(segments.last.text, tail);
      }
    }, tags: 'glados');
  });
}
