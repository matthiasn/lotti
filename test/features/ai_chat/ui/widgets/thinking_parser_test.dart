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
  });
}
