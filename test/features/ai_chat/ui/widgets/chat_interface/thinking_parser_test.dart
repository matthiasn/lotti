import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';

void main() {
  group('splitThinkingSegments', () {
    test('handles HTML <think> tags', () {
      const input = 'A<think>TH</think>B';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 3);
      expect(segs[0].isThinking, false);
      expect(segs[0].text, 'A');
      expect(segs[1].isThinking, true);
      expect(segs[1].text, 'TH');
      expect(segs[2].isThinking, false);
      expect(segs[2].text, 'B');
    });

    test('handles HTML <thinking> tags', () {
      const input = '<thinking>INNER</thinking> visible';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 2);
      expect(segs[0].isThinking, true);
      expect(segs[0].text.trim(), 'INNER');
      expect(segs[1].isThinking, false);
      expect(segs[1].text.trim(), 'visible');
    });

    test('handles bracket [think] tags', () {
      const input = 'x [think]RZ[/think] y';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 3);
      expect(segs[1].isThinking, true);
      expect(segs[1].text, 'RZ');
    });

    test('handles bracket [thinking] tags', () {
      const input = '[thinking]alpha[/thinking]beta';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 2);
      expect(segs[0].isThinking, true);
      expect(segs[0].text, 'alpha');
      expect(segs[1].isThinking, false);
      expect(segs[1].text, 'beta');
    });

    test('handles fenced ```think blocks', () {
      const input = 'pre```think\nT\n```post';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 3);
      expect(segs[0].text, 'pre');
      expect(segs[1].isThinking, true);
      expect(segs[1].text.trim(), 'T');
      expect(segs[2].text, 'post');
    });

    test('handles fenced ```thinking blocks', () {
      const input = '```thinking\nZZZ\n``` tail';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 2);
      expect(segs[0].isThinking, true);
      expect(segs[0].text.trim(), 'ZZZ');
      expect(segs[1].text.trim(), 'tail');
    });

    test('interleaves visible and multiple thinking segments', () {
      const input = 'v1<think>a</think>v2<thinking>b</thinking>v3';
      final segs = splitThinkingSegments(input);
      expect(segs.map((s) => s.isThinking).toList(),
          [false, true, false, true, false]);
      expect(segs.map((s) => s.text).toList(), ['v1', 'a', 'v2', 'b', 'v3']);
    });
  });

  group('parseThinking', () {
    test('aggregates thinking and returns visible text', () {
      const input = 'x<think>a</think>y<thinking>b</thinking>z';
      final parsed = parseThinking(input);
      // visible is the non-thinking pieces concatenated
      expect(parsed.visible, 'xyz');
      // thinking is the two blocks joined with hr in between by default parser
      expect(parsed.thinking, isNotNull);
      expect(parsed.thinking!.contains('a'), isTrue);
      expect(parsed.thinking!.contains('b'), isTrue);
    });
  });
}
