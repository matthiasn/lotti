import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_stream_utils.dart';

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
        ChatStreamUtils.closeRegexFromOpenToken('<thinking>')
            .hasMatch('</thinking>'),
        isTrue,
      );
      expect(
        ChatStreamUtils.closeRegexFromOpenToken('[thinking]')
            .hasMatch('[/thinking]'),
        isTrue,
      );
      expect(
        ChatStreamUtils.closeRegexFromOpenToken('```thinking\n')
            .hasMatch('```'),
        isTrue,
      );
    });
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
  });

  group('ChatStreamUtils.prepareVisibleChunk', () {
    test('returns null text and sets pending for whitespace+newline', () {
      final res =
          ChatStreamUtils.prepareVisibleChunk(' \n', pendingSoftBreak: false);
      expect(res.text, isNull);
      expect(res.pendingSoftBreak, isTrue);
    });

    test('upgrades to single newline when next is not structural', () {
      final res1 =
          ChatStreamUtils.prepareVisibleChunk('para', pendingSoftBreak: true);
      expect(res1.text!.startsWith('\n'), isTrue);
      expect(res1.text!.startsWith('\n\n'), isFalse);
      expect(res1.pendingSoftBreak, isFalse);
    });

    test('empty raw text yields empty text and preserves pending', () {
      final res =
          ChatStreamUtils.prepareVisibleChunk('', pendingSoftBreak: true);
      expect(res.text, '');
      expect(res.pendingSoftBreak, isTrue);
    });

    test('no pending soft break passes text through unchanged', () {
      final res =
          ChatStreamUtils.prepareVisibleChunk('hello', pendingSoftBreak: false);
      expect(res.text, 'hello');
      expect(res.pendingSoftBreak, isFalse);
    });
  });
}
