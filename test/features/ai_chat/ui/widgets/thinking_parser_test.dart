import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show Any, ExploreConfig, Generator, Glados, Glados2, StringAnys, any;
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';

// ---------------------------------------------------------------------------
// Generator helpers
// ---------------------------------------------------------------------------

extension _AnyX on Any {
  /// Generates a string of printable ASCII letters/digits (no tag characters).
  Generator<String> get safeText => any.letterOrDigits;
}

void main() {
  // -------------------------------------------------------------------------
  // ParsedThinking model
  // -------------------------------------------------------------------------

  group('ParsedThinking', () {
    test('stores visible and null thinking', () {
      const pt = ParsedThinking(visible: 'hello');
      expect(pt.visible, 'hello');
      expect(pt.thinking, isNull);
    });

    test('stores visible and non-null thinking', () {
      const pt = ParsedThinking(visible: 'answer', thinking: 'reason');
      expect(pt.visible, 'answer');
      expect(pt.thinking, 'reason');
    });
  });

  // -------------------------------------------------------------------------
  // ThinkingPatterns regex sanity checks (covers lines 53, 57, 63, 67)
  // -------------------------------------------------------------------------

  group('ThinkingPatterns', () {
    test('htmlOpen matches <think> and <thinking> case-insensitively', () {
      expect(ThinkingPatterns.htmlOpen.hasMatch('<think>'), isTrue);
      expect(ThinkingPatterns.htmlOpen.hasMatch('<THINKING>'), isTrue);
      expect(ThinkingPatterns.htmlOpen.hasMatch('<thinking>'), isTrue);
      expect(ThinkingPatterns.htmlOpen.hasMatch('<notthink>'), isFalse);
    });

    test('htmlClose matches </think> and </thinking> case-insensitively', () {
      expect(ThinkingPatterns.htmlClose.hasMatch('</think>'), isTrue);
      expect(ThinkingPatterns.htmlClose.hasMatch('</THINKING>'), isTrue);
      expect(ThinkingPatterns.htmlClose.hasMatch('</notthink>'), isFalse);
    });

    test('bracketOpen matches [think] and [thinking] case-insensitively', () {
      expect(ThinkingPatterns.bracketOpen.hasMatch('[think]'), isTrue);
      expect(ThinkingPatterns.bracketOpen.hasMatch('[THINKING]'), isTrue);
      expect(ThinkingPatterns.bracketOpen.hasMatch('[notthink]'), isFalse);
    });

    test(
      'bracketClose matches [/think] and [/thinking] case-insensitively',
      () {
        expect(ThinkingPatterns.bracketClose.hasMatch('[/think]'), isTrue);
        expect(ThinkingPatterns.bracketClose.hasMatch('[/THINKING]'), isTrue);
        expect(ThinkingPatterns.bracketClose.hasMatch('[notthink]'), isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // parseThinking — example-based
  // -------------------------------------------------------------------------

  group('parseThinking', () {
    test('returns empty visible for empty input', () {
      final result = parseThinking('');
      expect(result.visible, '');
      expect(result.thinking, isNull);
    });

    test('plain text with no tags returns full input as visible', () {
      const input = 'Hello, world!';
      final result = parseThinking(input);
      expect(result.visible, input);
      expect(result.thinking, isNull);
    });

    test('<think>...</think> tag separates thinking from visible', () {
      final result = parseThinking('<think>reason</think>answer');
      expect(result.visible, 'answer');
      expect(result.thinking, 'reason');
    });

    test('<thinking>...</thinking> tag works', () {
      final result = parseThinking('<thinking>step</thinking>reply');
      expect(result.visible, 'reply');
      expect(result.thinking, 'step');
    });

    test('bracket [think]...[/think] syntax works', () {
      final result = parseThinking('[think]thought[/think]visible');
      expect(result.visible, 'visible');
      expect(result.thinking, 'thought');
    });

    test('bracket [thinking]...[/thinking] syntax works', () {
      final result = parseThinking('[thinking]chain[/thinking]result');
      expect(result.visible, 'result');
      expect(result.thinking, 'chain');
    });

    test('fenced ```think block is extracted', () {
      final result = parseThinking('```think\nmy reasoning\n```\nthe answer');
      expect(result.visible, 'the answer');
      expect(result.thinking, isNotNull);
      expect(result.thinking, contains('my reasoning'));
    });

    test('fenced ```thinking block is extracted', () {
      final result = parseThinking(
        '```thinking\ndeep reasoning\n```\nfinal answer',
      );
      expect(result.visible, 'final answer');
      expect(result.thinking, contains('deep reasoning'));
    });

    test(
      'open-ended <thinking> tag (streaming): all after tag is thinking',
      () {
        final result = parseThinking('<thinking>still thinking...');
        expect(result.thinking, contains('still thinking...'));
        expect(result.visible, '');
      },
    );

    test('open-ended [think] tag (streaming)', () {
      final result = parseThinking('[think]partial');
      expect(result.thinking, contains('partial'));
    });

    test('open-ended fenced block (no closing ```)', () {
      final result = parseThinking('```think\nopen ended');
      expect(result.thinking, contains('open ended'));
    });

    test('text before and after thinking block is preserved', () {
      final result = parseThinking('before <think>inner</think> after');
      expect(result.visible.trim(), 'before  after'.trim());
      expect(result.thinking, 'inner');
    });

    test('multiple thinking blocks are concatenated with HR separator', () {
      final result = parseThinking(
        '<think>first</think>mid<think>second</think>end',
      );
      expect(result.visible, 'midend');
      expect(result.thinking, contains('first'));
      expect(result.thinking, contains('second'));
      expect(result.thinking, contains('---'));
    });

    test('case-insensitive: <THINK> is recognised', () {
      final result = parseThinking('<THINK>reasoning</THINK>answer');
      expect(result.thinking, isNotNull);
      expect(result.visible, 'answer');
    });

    test('nested thinking tags are handled (nesting depth)', () {
      final result = parseThinking(
        '<think>outer<think>inner</think>still outer</think>vis',
      );
      expect(result.thinking, contains('outer'));
      expect(result.thinking, contains('inner'));
      expect(result.visible, 'vis');
    });

    test(
      'unbalanced nesting where the only close lands at end of input is '
      'open-ended: whole remainder (incl. inner open) becomes thinking '
      '(covers _extractNested natural loop exit, line 144)',
      () {
        // One inner <think> raises depth to 2; the single </think> sits at the
        // very end of the string, dropping depth to 1 while pos reaches the end
        // of content. The while loop exits without depth==0 and without ever
        // seeing nextClose<0, hitting the final open-ended return.
        final result = parseThinking('<think>x<think>y</think>');
        expect(result.visible, '');
        // The inner open token and the trailing close are part of the body.
        expect(result.thinking, 'x<think>y</think>');
      },
    );

    test(
      'unbalanced nesting with surrounding visible text (line 144 path)',
      () {
        final result = parseThinking(
          'pre <think>a<think>b</think> post',
        );
        expect(result.visible, 'pre');
        expect(result.thinking, 'a<think>b</think> post');
      },
    );

    test(
      'bracket unbalanced nesting is also open-ended (line 144 via brackets)',
      () {
        final result = parseThinking('[think]p[think]q[/think]');
        expect(result.visible, '');
        expect(result.thinking, 'p[think]q[/think]');
      },
    );

    test(
      'ThinkingUtils.stripThinking removes thinking and returns visible',
      () {
        final stripped = ThinkingUtils.stripThinking('<think>hide</think>show');
        expect(stripped, 'show');
      },
    );

    test('result is memoised: same object returned on repeated call', () {
      const input = '<think>cached</think>result';
      final first = parseThinking(input);
      final second = parseThinking(input);
      expect(identical(first, second), isTrue);
    });

    test('cache eviction: more than _cacheLimit entries evicts oldest '
        '(covers line 92)', () {
      // Insert 102 unique entries to trigger eviction at _cacheLimit (100).
      for (var i = 0; i < 102; i++) {
        parseThinking('unique_entry_$i');
      }
      // After eviction the function still works correctly.
      final result = parseThinking('<think>ok</think>visible');
      expect(result.visible, 'visible');
      expect(result.thinking, 'ok');
    });

    test(
      'very long content > 10000 chars is not cached (two calls are equal)',
      () {
        final big = 'x' * 10001;
        final r1 = parseThinking(big);
        final r2 = parseThinking(big);
        // Results equal even though not cached.
        expect(r1.visible, r2.visible);
        expect(r1.thinking, r2.thinking);
      },
    );

    test('thinking content truncated when single segment exceeds max length '
        '(covers segment.length > remaining path)', () {
      final longThinking = 'a' * (ThinkingUtils.maxThinkingLength + 100);
      final result = parseThinking('<think>$longThinking</think>answer');
      expect(result.thinking, contains('[Thinking content truncated...]'));
    });

    test('thinking content truncated when second block fills remaining '
        '(covers line 365: remaining <= 0)', () {
      // First block fills up exactly maxThinkingLength characters.
      final full = 'a' * ThinkingUtils.maxThinkingLength;
      final result = parseThinking(
        '<think>$full</think>mid<think>overflow</think>end',
      );
      expect(result.thinking, contains('[Thinking content truncated...]'));
    });

    test('[think] and [thinking] both present: covers line 173 both-present '
        'branch', () {
      // [think] appears before [thinking] — parser picks the closer one first.
      final result = parseThinking('[think]a[/think][thinking]b[/thinking]end');
      expect(result.thinking, contains('a'));
      expect(result.visible, 'end');
    });

    test('<think> and <thinking> both present: <thinking> appears first', () {
      final result = parseThinking(
        '<thinking>first</thinking><think>second</think>end',
      );
      expect(result.thinking, contains('first'));
      expect(result.visible, 'end');
    });

    test('defensive: parseThinking never throws for plain strings', () {
      expect(() => parseThinking('no tags at all'), returnsNormally);
    });
  });

  // -------------------------------------------------------------------------
  // splitThinkingSegments — example-based
  // -------------------------------------------------------------------------

  group('splitThinkingSegments', () {
    test('empty string returns empty list', () {
      expect(splitThinkingSegments(''), isEmpty);
    });

    test('plain text yields single visible segment', () {
      final segments = splitThinkingSegments('hello');
      expect(segments, hasLength(1));
      expect(segments.first.isThinking, isFalse);
      expect(segments.first.text, 'hello');
    });

    test('<think>...</think> yields thinking segment then visible', () {
      final segments = splitThinkingSegments('<think>reason</think>answer');
      expect(segments, hasLength(2));
      expect(segments[0].isThinking, isTrue);
      expect(segments[0].text, 'reason');
      expect(segments[1].isThinking, isFalse);
      expect(segments[1].text, 'answer');
    });

    test('text before and after thinking segment is preserved', () {
      final segments = splitThinkingSegments(
        'before<think>middle</think>after',
      );
      expect(segments, hasLength(3));
      expect(segments[0].isThinking, isFalse);
      expect(segments[0].text, 'before');
      expect(segments[1].isThinking, isTrue);
      expect(segments[1].text, 'middle');
      expect(segments[2].isThinking, isFalse);
      expect(segments[2].text, 'after');
    });

    test('multiple thinking segments are each separate', () {
      final segments = splitThinkingSegments(
        '<think>a</think>mid<think>b</think>end',
      );
      final thinking = segments.where((s) => s.isThinking).toList();
      expect(thinking, hasLength(2));
      expect(thinking[0].text, 'a');
      expect(thinking[1].text, 'b');
    });

    test('open-ended <think> (streaming) is a thinking segment', () {
      final segments = splitThinkingSegments('<think>streaming...');
      expect(segments, hasLength(1));
      expect(segments.first.isThinking, isTrue);
      expect(segments.first.text, contains('streaming...'));
    });

    test('fence open-ended (no closing ```) yields thinking segment '
        '(covers lines 422-423)', () {
      final segments = splitThinkingSegments('```think\nno close');
      expect(segments, hasLength(1));
      expect(segments.first.isThinking, isTrue);
      expect(segments.first.text, contains('no close'));
    });

    test('bracket [thinking] tag yields thinking segment', () {
      final segments = splitThinkingSegments(
        '[thinking]content[/thinking]visible',
      );
      expect(segments, hasLength(2));
      expect(segments[0].isThinking, isTrue);
      expect(segments[0].text, 'content');
      expect(segments[1].isThinking, isFalse);
      expect(segments[1].text, 'visible');
    });

    test(
      'no visible tail after last thinking block produces correct count',
      () {
        final segments = splitThinkingSegments('<think>only thinking</think>');
        final thinkingSegs = segments.where((s) => s.isThinking).toList();
        expect(thinkingSegs, hasLength(1));
        expect(thinkingSegs.first.text, 'only thinking');
      },
    );

    test('fenced ```thinking block is extracted as thinking segment', () {
      final segments = splitThinkingSegments(
        'before\n```thinking\ndeep\n```\nafter',
      );
      final thinking = segments.where((s) => s.isThinking).toList();
      expect(thinking, hasLength(1));
      expect(thinking.first.text, contains('deep'));
    });

    test(
      'unbalanced nesting (only close at end) is one open-ended thinking '
      'segment carrying the inner open token (covers line 144 via split)',
      () {
        final segments = splitThinkingSegments(
          'pre <think>a<think>b</think> post',
        );
        expect(segments, hasLength(2));
        expect(segments[0].isThinking, isFalse);
        expect(segments[0].text, 'pre ');
        expect(segments[1].isThinking, isTrue);
        expect(segments[1].text, 'a<think>b</think> post');
      },
    );
  });

  // -------------------------------------------------------------------------
  // Property-based tests (glados)
  // -------------------------------------------------------------------------

  group('parseThinking property tests', () {
    // Invariant: parseThinking never throws for any letter/digit string.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 200)).test(
      'never throws for arbitrary letter/digit string input',
      (String input) {
        expect(() => parseThinking(input), returnsNormally);
      },
      tags: 'glados',
    );

    // Invariant: visible is always a non-null string.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 200)).test(
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
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 200)).test(
      'plain text: visible equals input, thinking is null',
      (String input) {
        final result = parseThinking(input);
        expect(result.visible.trim(), input.trim());
        expect(result.thinking, isNull);
      },
      tags: 'glados',
    );

    // Invariant: splitThinkingSegments never throws.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 200)).test(
      'splitThinkingSegments never throws for letter/digit input',
      (String input) {
        expect(() => splitThinkingSegments(input), returnsNormally);
      },
      tags: 'glados',
    );

    // Invariant: for plain text (no tag characters), splitThinkingSegments
    // returns at most one segment whose text equals the input exactly.
    Glados<String>(any.letterOrDigits, ExploreConfig(numRuns: 200)).test(
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
