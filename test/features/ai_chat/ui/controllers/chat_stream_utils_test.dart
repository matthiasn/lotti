import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/ui/controllers/chat_stream_utils.dart';
import 'chat_stream_utils_test_helpers.dart';

void main() {
  group('ChatStreamUtils.computeOpenTagCarry', () {
    test('returns partial HTML opener suffix', () {
      expect(ChatStreamUtils.computeOpenTagCarry('abc<thin'), '<thin');
      expect(ChatStreamUtils.computeOpenTagCarry('abc<thinking'), '<thinking');
    });

    test('returns empty for complete HTML opener', () {
      expect(ChatStreamUtils.computeOpenTagCarry('<thinking>'), isEmpty);
      expect(ChatStreamUtils.computeOpenTagCarry('<thinking >   '), isEmpty);
    });

    test('handles bracket partial and complete openers', () {
      expect(ChatStreamUtils.computeOpenTagCarry('[thin'), '[thin');
      expect(ChatStreamUtils.computeOpenTagCarry('[thinking]   '), isEmpty);
    });

    test('returns partial fenced opener suffix', () {
      expect(ChatStreamUtils.computeOpenTagCarry('```thin'), '```thin');
      expect(ChatStreamUtils.computeOpenTagCarry('```thinking'), '```thinking');
    });

    test('returns empty for complete fenced opener with newline', () {
      expect(ChatStreamUtils.computeOpenTagCarry('```thinking\n'), isEmpty);
      expect(ChatStreamUtils.computeOpenTagCarry('```think \n  '), isEmpty);
    });

    test('handles empty input', () {
      expect(ChatStreamUtils.computeOpenTagCarry(''), isEmpty);
    });

    glados.Glados(
      glados.any.generatedOpenCarryScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test(
      'carry is a suffix of the input, never longer, and never a full opener',
      (scenario) {
        final input = scenario.input;
        final carry = ChatStreamUtils.computeOpenTagCarry(input);

        // Invariant 1: carry length never exceeds the input length.
        expect(
          carry.length,
          lessThanOrEqualTo(input.length),
          reason: '$scenario',
        );

        // Invariant 2: carry is always a (possibly empty) suffix of the input.
        expect(input.endsWith(carry), isTrue, reason: '$scenario');

        // Invariant 3: a non-empty carry is always a case-insensitive prefix of
        // one of the partial opener candidates (which deliberately exclude the
        // closing character), so it can never itself be a complete opener.
        if (carry.isNotEmpty) {
          final lowerCarry = carry.toLowerCase();
          final matchesCandidatePrefix = openTagCandidates.any(
            (candidate) => candidate.startsWith(lowerCarry),
          );
          expect(matchesCandidatePrefix, isTrue, reason: '$scenario');

          // It also never matches a full-opener regex.
          for (final re in fullOpenerRegexes) {
            expect(re.hasMatch(carry), isFalse, reason: '$scenario');
          }
        }

        // Invariant 4: a complete opener at the tail produces no carry.
        if (scenario.tailIsCompleteOpener) {
          expect(carry, isEmpty, reason: '$scenario');
        }
      },
      tags: 'glados',
    );
  });

  group('ChatStreamUtils.shouldUpgradeSoftBreak', () {
    test('detects headings and list starts', () {
      expect(ChatStreamUtils.shouldUpgradeSoftBreak('# Title'), isTrue);
      expect(ChatStreamUtils.shouldUpgradeSoftBreak('  - item'), isTrue);
      expect(ChatStreamUtils.shouldUpgradeSoftBreak('2. item'), isTrue);
    });

    test('non-structural text does not upgrade', () {
      expect(ChatStreamUtils.shouldUpgradeSoftBreak('paragraph'), isFalse);
      expect(ChatStreamUtils.shouldUpgradeSoftBreak('  text'), isFalse);
    });
  });

  group('ChatStreamUtils.wrapThinkingBlock', () {
    test('wraps text with thinking tags and newlines', () {
      expect(
        ChatStreamUtils.wrapThinkingBlock('inner'),
        '<thinking>\ninner\n</thinking>',
      );
    });
  });

  group('ChatStreamUtils.closeRegexFromOpenToken', () {
    test('returns correct close regex for token kinds', () {
      expect(
        ChatStreamUtils.closeRegexFromOpenToken(
          '<thinking>',
        ).hasMatch('</thinking>'),
        isTrue,
      );
      expect(
        ChatStreamUtils.closeRegexFromOpenToken(
          '[thinking]',
        ).hasMatch('[/thinking]'),
        isTrue,
      );
      expect(
        ChatStreamUtils.closeRegexFromOpenToken(
          '```thinking\n',
        ).hasMatch('```'),
        isTrue,
      );
    });

    test('carries partial custom close tokens from the active token', () {
      expect(
        ChatStreamUtils.computeCloseTagCarry('body</thou', '</thought>'),
        '</thou',
      );
      expect(
        ChatStreamUtils.computeCloseTagCarry('body[/custom  ', '[/custom]'),
        '[/custom  ',
      );
    });

    glados.Glados(
      glados.any.generatedCloseCarryScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'carries generated partial close tokens without swallowing body text',
      (scenario) {
        expect(
          ChatStreamUtils.computeCloseTagCarry(
            scenario.segment,
            scenario.activeCloseToken,
          ),
          scenario.expectedCarry,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });

  group('ChatStreamUtils.findEarliestOpenMatch', () {
    test('picks the earliest of multiple token kinds', () {
      const s = 'xx[thinking]a[/thinking] yy <thinking>z</thinking>';
      final m = ChatStreamUtils.findEarliestOpenMatch(s, 0);
      expect(m, isNotNull);
      expect(m!.idx, 2); // '[' at position 2
    });

    test('returns null when no opener present', () {
      const s = 'no openers here';
      final m = ChatStreamUtils.findEarliestOpenMatch(s, 0);
      expect(m, isNull);
    });

    test('handles fenced opener earlier than html/bracket', () {
      const s =
          'aa```thinking\n body``` <thinking>x</thinking> [thinking]y[/thinking]';
      final m = ChatStreamUtils.findEarliestOpenMatch(s, 0);
      expect(m, isNotNull);
      expect(m!.idx, 2); // backticks at position 2
      expect(m.closeToken, '```');
    });
  });

  group('ChatStreamUtils.isWhitespaceWithLineBreak', () {
    test('detects whitespace with newline only', () {
      expect(ChatStreamUtils.isWhitespaceWithLineBreak(' \n '), isTrue);
      expect(ChatStreamUtils.isWhitespaceWithLineBreak('   '), isFalse);
      expect(ChatStreamUtils.isWhitespaceWithLineBreak('a\n'), isFalse);
    });
  });

  group('ChatStreamUtils.truncateWithEllipsis', () {
    test('no-op when under cap', () {
      expect(ChatStreamUtils.truncateWithEllipsis('abc', 5), 'abc');
    });

    test('no-op when exactly at cap', () {
      expect(ChatStreamUtils.truncateWithEllipsis('abc', 3), 'abc');
      expect(ChatStreamUtils.isTruncated('abc'), isFalse);
    });

    test('truncates and adds single ellipsis when exceeding cap', () {
      final content = 'a' * 10;
      final out = ChatStreamUtils.truncateWithEllipsis(content, 6);
      expect(out, equals('aaaaaa${ChatStreamUtils.ellipsis}'));
      expect(ChatStreamUtils.isTruncated(out), isTrue);
    });

    glados.Glados(
      glados.any.generatedTruncationScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated truncation and ellipsis model',
      (scenario) {
        final result = ChatStreamUtils.truncateWithEllipsis(
          scenario.content,
          scenario.cap,
        );

        expect(result, scenario.expected, reason: '$scenario');
        expect(
          ChatStreamUtils.isTruncated(result),
          scenario.shouldTruncate,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });

  group('ChatStreamUtils.prepareVisibleChunk', () {
    test('returns null text and sets pending for whitespace+newline', () {
      final res = ChatStreamUtils.prepareVisibleChunk(
        ' \n',
        pendingSoftBreak: false,
      );
      expect(res.text, isNull);
      expect(res.pendingSoftBreak, isTrue);
    });

    test('upgrades to single newline when next is not structural', () {
      final res1 = ChatStreamUtils.prepareVisibleChunk(
        'para',
        pendingSoftBreak: true,
      );
      expect(res1.text!.startsWith('\n'), isTrue);
      expect(res1.text!.startsWith('\n\n'), isFalse);
      expect(res1.pendingSoftBreak, isFalse);
    });

    test('empty raw text yields empty text and preserves pending', () {
      final res = ChatStreamUtils.prepareVisibleChunk(
        '',
        pendingSoftBreak: true,
      );
      expect(res.text, '');
      expect(res.pendingSoftBreak, isTrue);
    });

    test('no pending soft break passes text through unchanged', () {
      final res = ChatStreamUtils.prepareVisibleChunk(
        'hello',
        pendingSoftBreak: false,
      );
      expect(res.text, 'hello');
      expect(res.pendingSoftBreak, isFalse);
    });

    glados.Glados(
      glados.any.generatedVisibleChunkScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated visible-chunk soft-break model',
      (scenario) {
        final result = ChatStreamUtils.prepareVisibleChunk(
          scenario.rawText,
          pendingSoftBreak: scenario.pendingSoftBreak,
        );

        expect(result.text, scenario.expectedText, reason: '$scenario');
        expect(
          result.pendingSoftBreak,
          scenario.expectedPendingSoftBreak,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });
}
