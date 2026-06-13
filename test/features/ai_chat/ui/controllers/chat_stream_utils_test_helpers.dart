import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/ui/controllers/chat_stream_utils.dart';

/// Partial opener candidates mirrored from
/// `ChatStreamUtils.computeOpenTagCarry` (lowercase, closing char excluded).
const openTagCandidates = <String>[
  '<thinking',
  '<think',
  '[thinking',
  '[think',
  '```thinking',
  '```think',
];

/// Full-opener regexes mirrored from `ChatStreamUtils.computeOpenTagCarry`.
final fullOpenerRegexes = <RegExp>[
  RegExp(r'<think(?:ing)?\s*>\s*$', caseSensitive: false),
  RegExp(r'\[(?:think|thinking)\s*\]\s*$', caseSensitive: false),
  RegExp(r'```[ \t]*(?:think|thinking)[ \t]*\n\s*$', caseSensitive: false),
];

/// Shape of the tail appended to the generated body for open-carry scenarios.
enum GeneratedOpenCarryTail {
  /// No special tail — exercises the "no carry" path with plain text.
  none,

  /// A partial opener prefix (closing char excluded), e.g. `<thin`.
  partialOpener,

  /// A complete opener, e.g. `<thinking>` / `[thinking]` / ```` ```thinking\n````.
  completeOpener,
}

enum GeneratedOpenTokenKind { html, bracket, fence }

class GeneratedOpenCarryScenario {
  const GeneratedOpenCarryScenario({
    required this.body,
    required this.tail,
    required this.kind,
    required this.prefixLength,
  });

  final List<GeneratedStreamUtilsTextToken> body;
  final GeneratedOpenCarryTail tail;
  final GeneratedOpenTokenKind kind;

  /// How much of the partial opener to keep (clamped to candidate length).
  final int prefixLength;

  String get _partialOpenerCandidate => switch (kind) {
    GeneratedOpenTokenKind.html => '<thinking',
    GeneratedOpenTokenKind.bracket => '[thinking',
    GeneratedOpenTokenKind.fence => '```thinking',
  };

  String get _completeOpener => switch (kind) {
    GeneratedOpenTokenKind.html => '<thinking>',
    GeneratedOpenTokenKind.bracket => '[thinking]',
    GeneratedOpenTokenKind.fence => '```thinking\n',
  };

  bool get tailIsCompleteOpener =>
      tail == GeneratedOpenCarryTail.completeOpener;

  /// Number of leading chars of the partial opener to keep, kept within
  /// `[1, candidate length]` without relying on `num`-typed `clamp`.
  int get _partialLength {
    final maxLen = _partialOpenerCandidate.length;
    if (prefixLength < 1) return 1;
    if (prefixLength > maxLen) return maxLen;
    return prefixLength;
  }

  String get _tailText => switch (tail) {
    GeneratedOpenCarryTail.none => '',
    GeneratedOpenCarryTail.partialOpener => _partialOpenerCandidate.substring(
      0,
      _partialLength,
    ),
    GeneratedOpenCarryTail.completeOpener => _completeOpener,
  };

  String get input => '${body.text}$_tailText';

  @override
  String toString() {
    return 'GeneratedOpenCarryScenario('
        'input: $input, '
        'tail: $tail, '
        'kind: $kind, '
        'prefixLength: $prefixLength)';
  }
}

enum GeneratedCloseTokenKind { html, bracket, fence }

enum GeneratedStreamUtilsTextToken {
  word,
  number,
  space,
  punctuation,
  markdown,
}

enum GeneratedVisibleChunkShape {
  empty,
  whitespaceLineBreak,
  heading,
  bullet,
  numberedList,
  paragraph,
}

class GeneratedCloseCarryScenario {
  const GeneratedCloseCarryScenario({
    required this.kind,
    required this.prefixLength,
    required this.body,
  });

  final GeneratedCloseTokenKind kind;
  final int prefixLength;
  final List<GeneratedStreamUtilsTextToken> body;

  String get activeCloseToken => switch (kind) {
    GeneratedCloseTokenKind.html => '</thinking>',
    GeneratedCloseTokenKind.bracket => '[/thinking]',
    GeneratedCloseTokenKind.fence => '```',
  };

  String get closeToken => switch (kind) {
    GeneratedCloseTokenKind.html => '</thinking>',
    GeneratedCloseTokenKind.bracket => '[/thinking]',
    GeneratedCloseTokenKind.fence => '```',
  };

  String get expectedCarry => closeToken.substring(0, prefixLength);

  String get segment => '${body.text}$expectedCarry';

  @override
  String toString() {
    return 'GeneratedCloseCarryScenario('
        'segment: $segment, '
        'activeCloseToken: $activeCloseToken, '
        'expectedCarry: $expectedCarry)';
  }
}

class GeneratedTruncationScenario {
  const GeneratedTruncationScenario({
    required this.tokens,
    required this.cap,
  });

  final List<GeneratedStreamUtilsTextToken> tokens;
  final int cap;

  String get content => tokens.text;

  bool get shouldTruncate => content.length > cap;

  String get expected => shouldTruncate
      ? '${content.substring(0, cap)}${ChatStreamUtils.ellipsis}'
      : content;

  @override
  String toString() =>
      'GeneratedTruncationScenario(content: $content, cap: $cap)';
}

class GeneratedVisibleChunkScenario {
  const GeneratedVisibleChunkScenario({
    required this.shape,
    required this.pendingSoftBreak,
  });

  final GeneratedVisibleChunkShape shape;
  final bool pendingSoftBreak;

  String get rawText => switch (shape) {
    GeneratedVisibleChunkShape.empty => '',
    GeneratedVisibleChunkShape.whitespaceLineBreak => ' \t\n ',
    GeneratedVisibleChunkShape.heading => '# Heading',
    GeneratedVisibleChunkShape.bullet => '  - item',
    GeneratedVisibleChunkShape.numberedList => '2. item',
    GeneratedVisibleChunkShape.paragraph => 'paragraph',
  };

  bool get _isStructural => switch (shape) {
    GeneratedVisibleChunkShape.heading ||
    GeneratedVisibleChunkShape.bullet ||
    GeneratedVisibleChunkShape.numberedList => true,
    _ => false,
  };

  String? get expectedText {
    if (shape == GeneratedVisibleChunkShape.empty) return '';
    if (shape == GeneratedVisibleChunkShape.whitespaceLineBreak) return null;
    if (!pendingSoftBreak) return rawText;
    return '${_isStructural ? '\n\n' : '\n'}$rawText';
  }

  bool get expectedPendingSoftBreak {
    if (shape == GeneratedVisibleChunkShape.empty) return pendingSoftBreak;
    return shape == GeneratedVisibleChunkShape.whitespaceLineBreak;
  }

  @override
  String toString() {
    return 'GeneratedVisibleChunkScenario('
        'shape: $shape, '
        'pendingSoftBreak: $pendingSoftBreak, '
        'rawText: $rawText)';
  }
}

extension on GeneratedStreamUtilsTextToken {
  String get text => switch (this) {
    GeneratedStreamUtilsTextToken.word => 'alpha',
    GeneratedStreamUtilsTextToken.number => '42',
    GeneratedStreamUtilsTextToken.space => ' ',
    GeneratedStreamUtilsTextToken.punctuation => '.,:;!?',
    GeneratedStreamUtilsTextToken.markdown => '- item',
  };
}

extension on List<GeneratedStreamUtilsTextToken> {
  String get text => map((token) => token.text).join();
}

extension AnyChatStreamUtils on glados.Any {
  glados.Generator<GeneratedCloseTokenKind> get _closeTokenKind =>
      glados.AnyUtils(this).choose(GeneratedCloseTokenKind.values);

  glados.Generator<GeneratedStreamUtilsTextToken> get _textToken =>
      glados.AnyUtils(this).choose(GeneratedStreamUtilsTextToken.values);

  glados.Generator<List<GeneratedStreamUtilsTextToken>> get _textTokens =>
      glados.ListAnys(this).listWithLengthInRange(0, 8, _textToken);

  glados.Generator<GeneratedVisibleChunkShape> get _visibleChunkShape =>
      glados.AnyUtils(this).choose(GeneratedVisibleChunkShape.values);

  glados.Generator<GeneratedOpenCarryTail> get _openCarryTail =>
      glados.AnyUtils(this).choose(GeneratedOpenCarryTail.values);

  glados.Generator<GeneratedOpenTokenKind> get _openTokenKind =>
      glados.AnyUtils(this).choose(GeneratedOpenTokenKind.values);

  glados.Generator<bool> get _boolean =>
      glados.AnyUtils(this).choose(const [true, false]);

  glados.Generator<GeneratedCloseCarryScenario>
  get generatedCloseCarryScenario => glados.CombinableAny(this).combine3(
    _closeTokenKind,
    glados.IntAnys(this).intInRange(1, 10),
    _textTokens,
    (
      GeneratedCloseTokenKind kind,
      int prefixLength,
      List<GeneratedStreamUtilsTextToken> body,
    ) => GeneratedCloseCarryScenario(
      kind: kind,
      prefixLength: prefixLength > kind.maxPrefixLength
          ? kind.maxPrefixLength
          : prefixLength,
      body: body,
    ),
  );

  glados.Generator<GeneratedOpenCarryScenario> get generatedOpenCarryScenario =>
      glados.CombinableAny(this).combine4(
        _textTokens,
        _openCarryTail,
        _openTokenKind,
        glados.IntAnys(this).intInRange(1, 12),
        (
          List<GeneratedStreamUtilsTextToken> body,
          GeneratedOpenCarryTail tail,
          GeneratedOpenTokenKind kind,
          int prefixLength,
        ) => GeneratedOpenCarryScenario(
          body: body,
          tail: tail,
          kind: kind,
          prefixLength: prefixLength,
        ),
      );

  glados.Generator<GeneratedTruncationScenario>
  get generatedTruncationScenario => glados.CombinableAny(this).combine2(
    _textTokens,
    glados.IntAnys(this).intInRange(0, 40),
    (
      List<GeneratedStreamUtilsTextToken> tokens,
      int cap,
    ) => GeneratedTruncationScenario(tokens: tokens, cap: cap),
  );

  glados.Generator<GeneratedVisibleChunkScenario>
  get generatedVisibleChunkScenario => glados.CombinableAny(this).combine2(
    _visibleChunkShape,
    _boolean,
    (
      GeneratedVisibleChunkShape shape,
      bool pendingSoftBreak,
    ) => GeneratedVisibleChunkScenario(
      shape: shape,
      pendingSoftBreak: pendingSoftBreak,
    ),
  );
}

extension on GeneratedCloseTokenKind {
  int get maxPrefixLength => switch (this) {
    GeneratedCloseTokenKind.html => '</thinking>'.length - 1,
    GeneratedCloseTokenKind.bracket => '[/thinking]'.length - 1,
    GeneratedCloseTokenKind.fence => '```'.length - 1,
  };
}
