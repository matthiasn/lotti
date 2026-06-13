import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show ExploreConfig, Glados, Glados2, StringAnys, any;
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';
import 'thinking_parser_test_helpers.dart';

void main() {
  // -------------------------------------------------------------------------
  // ParsedThinking model
  // -------------------------------------------------------------------------

  group('parseThinking property tests', () {
    // Invariant: parseThinking never throws for any letter/digit string.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 180)).test(
      'never throws for arbitrary letter/digit string input',
      (String input) {
        expect(() => parseThinking(input), returnsNormally);
      },
      tags: 'glados',
    );

    // Invariant: visible is always a non-null string.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 180)).test(
      'visible is always a non-null string',
      (String input) {
        final result = parseThinking(input);
        expect(result.visible, isA<String>());
      },
      tags: 'glados',
    );

    // Invariant: for a well-formed closed <think> tag, thinking == body and
    // visible == tail, where body and tail are safe (no tag characters).
    Glados2<String, String>(
      any.safeText,
      any.safeText,
      ExploreConfig(numRuns: 120),
    ).test(
      'single closed <think> tag: thinking equals body, visible equals tail',
      (String body, String tail) {
        final input = '<think>$body</think>$tail';
        final result = parseThinking(input);
        expect(result.thinking?.trim(), body.trim());
        expect(result.visible.trim(), tail.trim());
      },
      tags: 'glados',
    );

    // Invariant: for plain text (no think markers), the entire input is
    // returned as visible and thinking is null.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 180)).test(
      'plain text: visible equals input, thinking is null',
      (String input) {
        final result = parseThinking(input);
        expect(result.visible.trim(), input.trim());
        expect(result.thinking, isNull);
      },
      tags: 'glados',
    );

    // Streaming invariant: cutting the input mid-body (as a streaming
    // consumer would when re-parsing the accumulated text each frame)
    // yields an open-ended thinking block containing exactly the body
    // prefix, with no visible text leaked.
    Glados2<String, String>(
      any.safeText,
      any.safeText,
      ExploreConfig(numRuns: 120),
    ).test(
      'streaming prefix mid-body: open-ended thinking, nothing visible',
      (String body, String tail) {
        if (body.trim().isEmpty) return;
        final cut = body.length ~/ 2;
        final prefix = '<think>${body.substring(0, cut)}';
        final result = parseThinking(prefix);
        expect(
          result.thinking?.trim(),
          body.substring(0, cut).trim(),
          reason: 'prefix="$prefix"',
        );
        expect(result.visible.trim(), isEmpty, reason: 'prefix="$prefix"');
      },
      tags: 'glados',
    );

    // Invariant: splitThinkingSegments never throws.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 180)).test(
      'splitThinkingSegments never throws for letter/digit input',
      (String input) {
        expect(() => splitThinkingSegments(input), returnsNormally);
      },
      tags: 'glados',
    );

    // Invariant: for plain text (no tag characters), splitThinkingSegments
    // returns at most one segment whose text equals the input exactly.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 180)).test(
      'splitThinkingSegments: plain text reproduces input exactly',
      (String input) {
        final segments = splitThinkingSegments(input);
        if (input.isEmpty) {
          expect(segments, isEmpty);
        } else {
          expect(segments, hasLength(1));
          expect(segments.first.isThinking, isFalse);
          expect(segments.first.text, input);
        }
      },
      tags: 'glados',
    );

    // Invariant: for a well-formed single bracket [think] block, split returns
    // exactly one thinking segment whose text equals the body.
    Glados2<String, String>(
      any.safeText,
      any.safeText,
      ExploreConfig(numRuns: 120),
    ).test(
      'splitThinkingSegments: single closed [think] tag yields one thinking '
      'segment with correct body',
      (String body, String tail) {
        final input = '[think]$body[/think]$tail';
        final segments = splitThinkingSegments(input);
        final thinking = segments.where((s) => s.isThinking).toList();
        expect(thinking, hasLength(1));
        expect(thinking.first.text, body);
      },
      tags: 'glados',
    );
  });

  // ---------------------------------------------------------------------------
  // Tests merged from chat_interface/thinking_parser_test.dart
  // ---------------------------------------------------------------------------
  group('ThinkingParser chat_interface merged tests', () {
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
        expect(segs.map((s) => s.isThinking).toList(), [
          false,
          true,
          false,
          true,
          false,
        ]);
        expect(
          segs.map((s) => s.text).toList(),
          ['v1', 'a', 'v2', 'b', 'v3'],
        );
      });
    });

    group('parseThinking', () {
      test('aggregates thinking and returns visible text', () {
        const input = 'x<think>a</think>y<thinking>b</thinking>z';
        final parsed = parseThinking(input);
        expect(parsed.visible, 'xyz');
        expect(parsed.thinking, isNotNull);
        expect(parsed.thinking!.contains('a'), isTrue);
        expect(parsed.thinking!.contains('b'), isTrue);
      });

      test('handles open-ended HTML block (streaming)', () {
        const input = 'Hello <thinking>partial stream';
        final parsed = parseThinking(input);
        expect(parsed.visible.trim(), 'Hello');
        expect(parsed.thinking, isNotNull);
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
        expect(parsed.thinking!.startsWith('BODY'), isTrue);
      });

      test('enforces max thinking length with truncation notice', () {
        final long = 'A' * (ThinkingUtils.maxThinkingLength + 50);
        final input = '<thinking>$long</thinking>';
        final parsed = parseThinking(input);
        expect(parsed.visible, isEmpty);
        expect(parsed.thinking, isNotNull);
        expect(
          parsed.thinking!.endsWith('[Thinking content truncated...]'),
          isTrue,
        );
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
        expect(segs.map((s) => s.isThinking).toList(), [
          false,
          true,
          false,
          true,
          false,
        ]);
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
        expect(parsed.visible, 'xx');
        expect(parsed.thinking, isNotNull);
        final t = parsed.thinking!;
        final hrCount = '---'.allMatches(t).length;
        expect(hrCount, 1);
        expect(t, contains('a'));
        expect(t, contains('b'));
      });

      test('aggregating: empty first block does not add HR', () {
        const input = '<think></think>[think]B[/think]';
        final parsed = parseThinking(input);
        expect(parsed.visible, '');
        expect(parsed.thinking, isNotNull);
        final t = parsed.thinking!;
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
        expect(parsed.visible, input);
        expect(parsed.thinking, isNull);
      });
    });
  });
}
