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
      // ignore: unnecessary_null_checks
      expect(parsed.thinking!.contains('a'), isTrue);
      // ignore: unnecessary_null_checks
      expect(parsed.thinking!.contains('b'), isTrue);
    });

    test('handles open-ended HTML block (streaming)', () {
      const input = 'Hello <thinking>partial stream';
      final parsed = parseThinking(input);
      expect(parsed.visible.trim(), 'Hello');
      expect(parsed.thinking, isNotNull);
      // ignore: unnecessary_null_checks
      expect(parsed.thinking!.contains('partial stream'), isTrue);
    });

    test('handles nested think blocks', () {
      const input = '<think>outer <think>inner</think> end</think> tail';
      final parsed = parseThinking(input);
      expect(parsed.visible.trim(), 'tail');
      expect(parsed.thinking, isNotNull);
      expect(parsed.thinking, contains('outer'));
      expect(parsed.thinking, contains('inner'));
    });

    test('handles open-ended fenced block', () {
      const input = 'pre```think\nBODY without closing fence';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'pre');
      expect(parsed.thinking, isNotNull);
      // ignore: unnecessary_null_checks
      expect(parsed.thinking!.startsWith('BODY'), isTrue);
    });

    test('enforces max thinking length with truncation notice', () {
      final long = 'A' * (ThinkingUtils.maxThinkingLength + 50);
      final input = '<thinking>$long</thinking>';
      final parsed = parseThinking(input);
      expect(parsed.visible, isEmpty);
      expect(parsed.thinking, isNotNull);
      // ignore: unnecessary_null_checks
      expect(
          parsed.thinking!.endsWith('[Thinking content truncated...]'), isTrue);
    });

    test('memoization cache returns identical instance for same input', () {
      const input = 'X<think>Y</think>Z';
      final a = parseThinking(input);
      final b = parseThinking(input);
      expect(identical(a, b), isTrue);
    });
  });

  group('splitThinkingSegments — edge cases', () {
    test('no tokens returns single visible segment', () {
      const input = 'plain visible text only';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 1);
      expect(segs.single.isThinking, false);
      expect(segs.single.text, input);
    });

    test('thinking-only input returns single thinking segment', () {
      const input = '<think>only thinking</think>';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 1);
      expect(segs.single.isThinking, true);
      expect(segs.single.text, 'only thinking');
    });

    test('case-insensitive HTML/bracket detection', () {
      const input = 'a<ThInK>X</THINK>b[ThInKiNg]Y[/tHiNkInG]c';
      final segs = splitThinkingSegments(input);
      expect(segs.map((s) => s.isThinking).toList(),
          [false, true, false, true, false]);
      expect(segs.map((s) => s.text).toList(), ['a', 'X', 'b', 'Y', 'c']);
    });

    test('case-insensitive fenced detection with spaces/tabs', () {
      const input = 'pre```   THINK  \t\n  X\n```post';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 3);
      expect(segs[0].text, 'pre');
      expect(segs[1].isThinking, true);
      expect(segs[1].text, contains('X'));
      expect(segs[2].text, 'post');
    });

    test('fence without newline after language is ignored', () {
      const input = 'pre```think X\n```post';
      final segs = splitThinkingSegments(input);
      // Not recognized as a thinking fence; all remains visible
      expect(segs.length, 1);
      expect(segs.single.isThinking, false);
      expect(segs.single.text, input);
    });

    test('stray closing token is treated as visible', () {
      const input = 'hello </think> world';
      final segs = splitThinkingSegments(input);
      expect(segs.length, 1);
      expect(segs.single.isThinking, false);
      expect(segs.single.text, input);
    });

    test('long thinking segment not truncated in split mode', () {
      final long = 'X' * (ThinkingUtils.maxThinkingLength + 100);
      final segs = splitThinkingSegments('[think]$long[/think]');
      expect(segs.length, 1);
      expect(segs.single.isThinking, true);
      expect(segs.single.text.length, long.length);
    });
  });

  group('parseThinking — edge cases', () {
    test('thinking-only input yields empty visible', () {
      const input = '[thinking]abc[/thinking]';
      final parsed = parseThinking(input);
      expect(parsed.visible, isEmpty);
      expect(parsed.thinking, 'abc');
    });

    test('visible-only input yields null thinking', () {
      const input = 'no special tags here';
      final parsed = parseThinking(input);
      expect(parsed.visible, input);
      expect(parsed.thinking, isNull);
    });

    test('mixed-type nested not recursively parsed', () {
      const input = '[think]outer <think>inner</think> end[/think] tail';
      final parsed = parseThinking(input);
      expect(parsed.visible.trim(), 'tail');
      expect(parsed.thinking, isNotNull);
      // The inner HTML think block remains as literal text inside the bracket block
      expect(parsed.thinking, contains('outer'));
      expect(parsed.thinking, contains('<think>inner</think>'));
      expect(parsed.thinking, contains('end'));
    });

    test('mismatched closing treated as open-ended', () {
      const input = '<think>body [/think] tail';
      final parsed = parseThinking(input);
      expect(parsed.visible, '');
      expect(parsed.thinking, 'body [/think] tail');
    });

    test('nested bracket blocks close correctly', () {
      const input = '[think]a [think]b[/think] c[/think] tail';
      final parsed = parseThinking(input);
      expect(parsed.visible.trim(), 'tail');
      expect(parsed.thinking, isNotNull);
      expect(parsed.thinking, contains('a '));
      expect(parsed.thinking, contains('b'));
      expect(parsed.thinking, contains(' c'));
    });

    test('aggregating inserts HR between multiple blocks', () {
      const input = '<think>a</think>xx[think]b[/think]';
      final parsed = parseThinking(input);
      // visible is the middle 'xx'
      expect(parsed.visible, 'xx');
      expect(parsed.thinking, isNotNull);
      // Expect exactly one horizontal rule separator
      final t = parsed.thinking!; // ignore: unnecessary_non_null_assertion
      final hrCount = '---'
          .allMatches(t)
          .length; // number of times the HR appears in thinking
      expect(hrCount, 1);
      expect(t, contains('a'));
      expect(t, contains('b'));
    });

    test('aggregating: empty first block does not add HR', () {
      const input = '<think></think>[think]B[/think]';
      final parsed = parseThinking(input);
      expect(parsed.visible, '');
      expect(parsed.thinking, isNotNull);
      final t = parsed.thinking!; // ignore: unnecessary_non_null_assertion
      // Should be just 'B' without starting HR
      expect(t, 'B');
    });

    test('trimmed results for visible and thinking', () {
      const input = '  start <think>  inside  </think> end  ';
      final parsed = parseThinking(input);
      expect(parsed.visible, 'start  end');
      expect(parsed.thinking, 'inside');
    });

    test('stripThinking removes all thinking blocks', () {
      const input = 'a<think>t</think>b[think]u[/think]c```think\nX\n```d';
      final stripped = ThinkingUtils.stripThinking(input);
      expect(stripped, 'abcd');
    });

    test('fence requires newline after language (no CRLF support)', () {
      const input = 'pre```thinking\r\nY\r\n```post';
      final parsed = parseThinking(input);
      // Current implementation requires \n in the opener; CRLF opener not recognized
      expect(parsed.visible, input);
      expect(parsed.thinking, isNull);
    });
  });
}
