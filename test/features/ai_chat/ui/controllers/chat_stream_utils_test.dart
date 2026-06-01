import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

enum _GeneratedCloseTokenKind { html, bracket, fence }

enum _GeneratedStreamUtilsTextToken {
  word,
  number,
  space,
  punctuation,
  markdown,
}

enum _GeneratedVisibleChunkShape {
  empty,
  whitespaceLineBreak,
  heading,
  bullet,
  numberedList,
  paragraph,
}

class _GeneratedCloseCarryScenario {
  const _GeneratedCloseCarryScenario({
    required this.kind,
    required this.prefixLength,
    required this.body,
  });

  final _GeneratedCloseTokenKind kind;
  final int prefixLength;
  final List<_GeneratedStreamUtilsTextToken> body;

  String get activeCloseToken => switch (kind) {
    _GeneratedCloseTokenKind.html => '</thinking>',
    _GeneratedCloseTokenKind.bracket => '[/thinking]',
    _GeneratedCloseTokenKind.fence => '```',
  };

  String get closeToken => switch (kind) {
    _GeneratedCloseTokenKind.html => '</thinking>',
    _GeneratedCloseTokenKind.bracket => '[/thinking]',
    _GeneratedCloseTokenKind.fence => '```',
  };

  String get expectedCarry => closeToken.substring(0, prefixLength);

  String get segment => '${body.text}$expectedCarry';

  @override
  String toString() {
    return '_GeneratedCloseCarryScenario('
        'segment: $segment, '
        'activeCloseToken: $activeCloseToken, '
        'expectedCarry: $expectedCarry)';
  }
}

class _GeneratedTruncationScenario {
  const _GeneratedTruncationScenario({
    required this.tokens,
    required this.cap,
  });

  final List<_GeneratedStreamUtilsTextToken> tokens;
  final int cap;

  String get content => tokens.text;

  bool get shouldTruncate => content.length > cap;

  String get expected => shouldTruncate
      ? '${content.substring(0, cap)}${ChatStreamUtils.ellipsis}'
      : content;

  @override
  String toString() =>
      '_GeneratedTruncationScenario(content: $content, cap: $cap)';
}

class _GeneratedVisibleChunkScenario {
  const _GeneratedVisibleChunkScenario({
    required this.shape,
    required this.pendingSoftBreak,
  });

  final _GeneratedVisibleChunkShape shape;
  final bool pendingSoftBreak;

  String get rawText => switch (shape) {
    _GeneratedVisibleChunkShape.empty => '',
    _GeneratedVisibleChunkShape.whitespaceLineBreak => ' \t\n ',
    _GeneratedVisibleChunkShape.heading => '# Heading',
    _GeneratedVisibleChunkShape.bullet => '  - item',
    _GeneratedVisibleChunkShape.numberedList => '2. item',
    _GeneratedVisibleChunkShape.paragraph => 'paragraph',
  };

  bool get _isStructural => switch (shape) {
    _GeneratedVisibleChunkShape.heading ||
    _GeneratedVisibleChunkShape.bullet ||
    _GeneratedVisibleChunkShape.numberedList => true,
    _ => false,
  };

  String? get expectedText {
    if (shape == _GeneratedVisibleChunkShape.empty) return '';
    if (shape == _GeneratedVisibleChunkShape.whitespaceLineBreak) return null;
    if (!pendingSoftBreak) return rawText;
    return '${_isStructural ? '\n\n' : '\n'}$rawText';
  }

  bool get expectedPendingSoftBreak {
    if (shape == _GeneratedVisibleChunkShape.empty) return pendingSoftBreak;
    return shape == _GeneratedVisibleChunkShape.whitespaceLineBreak;
  }

  @override
  String toString() {
    return '_GeneratedVisibleChunkScenario('
        'shape: $shape, '
        'pendingSoftBreak: $pendingSoftBreak, '
        'rawText: $rawText)';
  }
}

extension on _GeneratedStreamUtilsTextToken {
  String get text => switch (this) {
    _GeneratedStreamUtilsTextToken.word => 'alpha',
    _GeneratedStreamUtilsTextToken.number => '42',
    _GeneratedStreamUtilsTextToken.space => ' ',
    _GeneratedStreamUtilsTextToken.punctuation => '.,:;!?',
    _GeneratedStreamUtilsTextToken.markdown => '- item',
  };
}

extension on List<_GeneratedStreamUtilsTextToken> {
  String get text => map((token) => token.text).join();
}

extension _AnyChatStreamUtils on glados.Any {
  glados.Generator<_GeneratedCloseTokenKind> get _closeTokenKind =>
      glados.AnyUtils(this).choose(_GeneratedCloseTokenKind.values);

  glados.Generator<_GeneratedStreamUtilsTextToken> get _textToken =>
      glados.AnyUtils(this).choose(_GeneratedStreamUtilsTextToken.values);

  glados.Generator<List<_GeneratedStreamUtilsTextToken>> get _textTokens =>
      glados.ListAnys(this).listWithLengthInRange(0, 8, _textToken);

  glados.Generator<_GeneratedVisibleChunkShape> get _visibleChunkShape =>
      glados.AnyUtils(this).choose(_GeneratedVisibleChunkShape.values);

  glados.Generator<bool> get _boolean =>
      glados.AnyUtils(this).choose(const [true, false]);

  glados.Generator<_GeneratedCloseCarryScenario>
  get generatedCloseCarryScenario => glados.CombinableAny(this).combine3(
    _closeTokenKind,
    glados.IntAnys(this).intInRange(1, 10),
    _textTokens,
    (
      _GeneratedCloseTokenKind kind,
      int prefixLength,
      List<_GeneratedStreamUtilsTextToken> body,
    ) => _GeneratedCloseCarryScenario(
      kind: kind,
      prefixLength: prefixLength > kind.maxPrefixLength
          ? kind.maxPrefixLength
          : prefixLength,
      body: body,
    ),
  );

  glados.Generator<_GeneratedTruncationScenario>
  get generatedTruncationScenario => glados.CombinableAny(this).combine2(
    _textTokens,
    glados.IntAnys(this).intInRange(0, 40),
    (
      List<_GeneratedStreamUtilsTextToken> tokens,
      int cap,
    ) => _GeneratedTruncationScenario(tokens: tokens, cap: cap),
  );

  glados.Generator<_GeneratedVisibleChunkScenario>
  get generatedVisibleChunkScenario => glados.CombinableAny(this).combine2(
    _visibleChunkShape,
    _boolean,
    (
      _GeneratedVisibleChunkShape shape,
      bool pendingSoftBreak,
    ) => _GeneratedVisibleChunkScenario(
      shape: shape,
      pendingSoftBreak: pendingSoftBreak,
    ),
  );
}

extension on _GeneratedCloseTokenKind {
  int get maxPrefixLength => switch (this) {
    _GeneratedCloseTokenKind.html => '</thinking>'.length - 1,
    _GeneratedCloseTokenKind.bracket => '[/thinking]'.length - 1,
    _GeneratedCloseTokenKind.fence => '```'.length - 1,
  };
}
