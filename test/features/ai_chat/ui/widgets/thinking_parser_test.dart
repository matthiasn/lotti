import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';

void main() {
  group('parseThinking', () {
    test('extracts html think block', () {
      const input = 'pre <think>secret</think> post';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'pre  post');
      expect(parsed.thinking, 'secret');
    });

    test('extracts fenced think block', () {
      const input = 'pre ```think\ninside\n``` post';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'pre  post');
      expect(parsed.thinking, 'inside');
    });

    test('extracts bracket think block', () {
      const input = 'pre [think]hidden[/think] post';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'pre  post');
      expect(parsed.thinking, 'hidden');
    });

    test('handles open-ended html think block', () {
      const input = 'pre <think>streaming';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'pre');
      expect(parsed.thinking, 'streaming');
    });

    test('handles open-ended fenced think block', () {
      const input = 'pre ```think\nstreaming';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'pre');
      expect(parsed.thinking, 'streaming');
    });

    test('handles open-ended bracket think block', () {
      const input = 'pre [think]streaming';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'pre');
      expect(parsed.thinking, 'streaming');
    });

    test('aggregates multiple think blocks across syntaxes', () {
      const input =
          'Intro <think>A</think> mid ```think\nB\n``` tail [think]C[/think] Done';
      final parsed = parseThinking(input);

      // Visible content should have all thinking stripped
      expect(parsed.visible.contains('Intro'), isTrue);
      expect(parsed.visible.contains('mid'), isTrue);
      expect(parsed.visible.contains('tail'), isTrue);
      expect(parsed.visible.contains('Done'), isTrue);
      expect(parsed.visible.contains('A'), isFalse);
      expect(parsed.visible.contains('B'), isFalse);
      expect(parsed.visible.contains('C'), isFalse);

      // Thinking content should concatenate in order with spacing
      expect(parsed.thinking, isNotNull);
      expect(parsed.thinking!.contains('A'), isTrue);
      expect(parsed.thinking!.contains('B'), isTrue);
      expect(parsed.thinking!.contains('C'), isTrue);
    });

    test('handles nested html-style blocks', () {
      const input = 'pre <think>outer <think>inner</think> end</think> post';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'pre  post');
      expect(parsed.thinking, contains('outer'));
      expect(parsed.thinking, contains('inner'));
    });

    test('mixed case tags are supported', () {
      const input = 'A <Think>Mixed</THINK> B [THINK]Case[/Think] C';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'A  B  C');
      expect(parsed.thinking, contains('Mixed'));
      expect(parsed.thinking, contains('Case'));
    });

    test('malformed/unclosed blocks are tolerated', () {
      const input = 'start <think>no end here';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'start');
      expect(parsed.thinking, contains('no end here'));
    });

    test('very long thinking is truncated with notice', () {
      final long = 'x' * (ThinkingUtils.maxThinkingLength + 1000);
      final parsed = parseThinking('<think>$long</think>');
      expect(parsed.visible, isEmpty);
      final thinking = parsed.thinking ?? '';
      expect(thinking.length,
          lessThanOrEqualTo(ThinkingUtils.maxThinkingLength + 100));
      expect(thinking, contains('truncated'));
    });

    test('ThinkingUtils.stripThinking removes all hidden content', () {
      const input =
          'pre <think>a</think> mid ```think\nb\n``` [think]c[/think] end';
      final visible = ThinkingUtils.stripThinking(input);
      expect(visible, 'pre  mid   end');
    });

    test('inserts markdown HR between segments', () {
      const input = 'X <think>one</think> Y [think]two[/think] Z';
      final parsed = parseThinking(input);
      final t = parsed.thinking ?? '';
      final hrCount = '---'.allMatches(t).length;
      expect(hrCount, 1);
      expect(t, contains('one'));
      expect(t, contains('two'));
    });

    test('memoizes parsed results for identical content', () {
      const input = 'Some <think>cache me</think> content';
      final a = parseThinking(input);
      final b = parseThinking(input);
      expect(identical(a, b), isTrue);
      expect(a.visible, equals(b.visible));
      expect(a.thinking, equals(b.thinking));
    });

    test('when thinking fills limit, extra segments append truncated notice', () {
      final exact = 'x' * ThinkingUtils.maxThinkingLength;
      final input = '<think>$exact</think> tail [think]more[/think]';
      final parsed = parseThinking(input);
      // Visible keeps non-thinking content intact
      expect(parsed.visible.trim(), 'tail');
      final t = parsed.thinking ?? '';
      // First segment fully included, then truncated notice is appended once.
      expect(t.startsWith(exact), isTrue);
      expect(t, contains('[Thinking content truncated...]'));
    });

    test('oversized content is not cached (no identical memoization)', () {
      // Build a single message exceeding the cache size threshold (> 10k).
      final big = 'x' * 12000;
      final input = '<think>$big</think>';
      final first = parseThinking(input);
      final second = parseThinking(input);
      // Should not be identical instances because large content is not cached.
      expect(identical(first, second), isFalse);
      expect(first.thinking, second.thinking);
      expect(first.visible, second.visible);
    });

    test('LRU cache evicts oldest entries when capacity exceeded', () {
      // Seed the cache with a key we can probe later.
      const key = 'seed <think>value</think>';
      final original = parseThinking(key);

      // Push many unique entries to exceed cache limit and trigger eviction.
      // Cache limit is 100; use more than that.
      for (var i = 0; i < 150; i++) {
        final s = 'k$i <think>v$i</think>';
        parseThinking(s);
      }

      // Re-parse the original key; if it was evicted, a new instance is made.
      final again = parseThinking(key);
      expect(identical(original, again), isFalse);
      expect(again.thinking, original.thinking);
      expect(again.visible, original.visible);
    });
  });
}
