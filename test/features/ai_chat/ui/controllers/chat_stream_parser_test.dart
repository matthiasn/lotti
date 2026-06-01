import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/ui/controllers/chat_stream_parser.dart';

void main() {
  group('ChatStreamParser', () {
    test('emits visible append for plain text', () {
      final p = ChatStreamParser();
      final events = p.processChunk('Hello world');
      expect(events.length, 1);
      expect(events.first, isA<VisibleAppend>());
      expect((events.first as VisibleAppend).text, 'Hello world');
      expect(p.finish(), isEmpty);
    });

    test('holds whitespace soft break then upgrades before heading', () {
      final p = ChatStreamParser();
      final e1 = p.processChunk('Intro');
      expect(e1.single, isA<VisibleAppend>());
      final e2 = p.processChunk(' \n');
      expect(e2, isEmpty);
      final e3 = p.processChunk('# Title');
      expect(e3.single, isA<VisibleAppend>());
      expect((e3.single as VisibleAppend).text, contains('\n\n# Title'));
    });

    test(
      'holds whitespace soft break then uses single newline before paragraph',
      () {
        final p = ChatStreamParser();
        // ignore: cascade_invocations
        p.processChunk('Intro');
        expect(p.processChunk(' \n'), isEmpty);
        final e3 = p.processChunk('paragraph');
        expect(e3.single, isA<VisibleAppend>());
        expect(
          (e3.single as VisibleAppend).text.startsWith('\nparagraph'),
          isTrue,
        );
        expect((e3.single as VisibleAppend).text.startsWith('\n\n'), isFalse);
      },
    );

    test('parses and finalizes HTML thinking block', () {
      final p = ChatStreamParser();
      final events = p.processChunk('<thinking>ABC</thinking>');
      expect(events.length, 1);
      expect(events.first, isA<ThinkingFinal>());
      expect((events.first as ThinkingFinal).text, 'ABC');
    });

    test('ignores empty thinking blocks', () {
      final p = ChatStreamParser();
      final events = p.processChunk('<thinking>  \n</thinking>');
      expect(events, isEmpty);
    });

    test('carries partial opener across chunks', () {
      final p = ChatStreamParser();
      // ignore: cascade_invocations
      p.processChunk('<thin');
      final e2 = p.processChunk('king>X</thinking>');
      expect(e2.length, 1);
      expect(e2.first, isA<ThinkingFinal>());
      expect((e2.first as ThinkingFinal).text, 'X');
    });

    test('carries partial bracket opener across chunks', () {
      final p = ChatStreamParser();
      // ignore: cascade_invocations
      p.processChunk('[thin');
      final e2 = p.processChunk('king]Y[/thinking]');
      expect(e2.length, 1);
      expect(e2.first, isA<ThinkingFinal>());
      expect((e2.first as ThinkingFinal).text, 'Y');
    });

    test('carries partial close token across chunks', () {
      final p = ChatStreamParser();
      final e1 = p.processChunk('<thinking>reasoning</thin');
      expect(e1, isEmpty);

      final e2 = p.processChunk('king>answer');
      expect(e2, hasLength(2));
      expect(e2.first, isA<ThinkingFinal>());
      expect((e2.first as ThinkingFinal).text, 'reasoning');
      expect(e2[1], isA<VisibleAppend>());
      expect((e2[1] as VisibleAppend).text, 'answer');
    });

    test('unterminated thinking is flushed on finish', () {
      final p = ChatStreamParser();
      final e1 = p.processChunk('<thinking>incomplete');
      expect(e1, isEmpty);
      final flushed = p.finish();
      expect(flushed.single, isA<ThinkingFinal>());
      expect((flushed.single as ThinkingFinal).text, 'incomplete');
    });

    test('finish flushes pending open-tag tail into thinking block', () {
      final p = ChatStreamParser();
      // Ends with a partial opener; carry should be '<thin'
      final e1 = p.processChunk('<thinking>abc<thin');
      expect(e1, isEmpty, reason: 'No close token yet, still inside thinking');
      final flushed = p.finish();
      expect(flushed.single, isA<ThinkingFinal>());
      expect((flushed.single as ThinkingFinal).text, 'abc<thin');
    });

    test(
      'finish emits pending open-tag tail as visible when not in thinking',
      () {
        final p = ChatStreamParser();
        final e1 = p.processChunk('before<thin');
        // Visible 'before' should emit immediately; '<thin' is carried
        expect(e1.single, isA<VisibleAppend>());
        expect((e1.single as VisibleAppend).text, 'before');
        final flushed = p.finish();
        expect(flushed.single, isA<VisibleAppend>());
        expect((flushed.single as VisibleAppend).text, '<thin');
      },
    );

    test('finish resets parser state for reuse', () {
      final p = ChatStreamParser();
      // Leave the parser mid-thinking with a pending tail
      // ignore: cascade_invocations
      p.processChunk('<thinking>x<thin');
      final flushed = p.finish();
      expect(flushed.single, isA<ThinkingFinal>());
      // After finish, parser should accept new content as fresh visible text
      final next = p.processChunk('OK');
      expect(next.single, isA<VisibleAppend>());
      expect((next.single as VisibleAppend).text, 'OK');
      expect(p.finish(), isEmpty);
    });

    test('whitespace-only unterminated thinking is not flushed', () {
      final p = ChatStreamParser();
      // ignore: cascade_invocations
      p.processChunk('<thinking>   ');
      final flushed = p.finish();
      expect(flushed, isEmpty);
    });

    test('finish flushes pending visible soft break at end of stream', () {
      final p = ChatStreamParser();
      expect(p.processChunk('Intro'), hasLength(1));
      expect(p.processChunk(' \n'), isEmpty);
      final flushed = p.finish();
      expect(flushed.single, isA<VisibleAppend>());
      expect((flushed.single as VisibleAppend).text, '\n');
    });

    test('fenced thinking block', () {
      final p = ChatStreamParser();
      final e = p.processChunk('before```think\nT\n```after');
      expect(e.length, 3);
      expect(e.first, isA<VisibleAppend>());
      expect((e.first as VisibleAppend).text, 'before');
      expect(e[1], isA<ThinkingFinal>());
      expect((e[1] as ThinkingFinal).text.trim(), 'T');
      expect(e[2], isA<VisibleAppend>());
      expect((e[2] as VisibleAppend).text, 'after');
      final rest = p.processChunk(' tail');
      expect(rest.single, isA<VisibleAppend>());
      expect((rest.single as VisibleAppend).text, ' tail');
    });

    test('case-insensitive tag parsing', () {
      final p = ChatStreamParser();
      final e = p.processChunk('<ThInKiNg>Y</ThiNkInG>');
      expect(e.single, isA<ThinkingFinal>());
      expect((e.single as ThinkingFinal).text, 'Y');
    });

    test(
      'nested thinking emits first closed block content (non-nested parser)',
      () {
        final p = ChatStreamParser();
        final e = p.processChunk(
          '<thinking>outer <thinking>inner</thinking> end</thinking>',
        );
        expect(e.isNotEmpty, isTrue);
        final tf = e.whereType<ThinkingFinal>().first;
        final text = tf.text;
        expect(text.contains('outer'), isTrue);
        expect(text.contains('inner'), isTrue);
        // Parser is not nested-aware; it may not include trailing 'end'.
      },
    );

    glados.Glados(
      glados.any.generatedChatStreamScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'emits the same semantic events for generated arbitrary chunking',
      (scenario) {
        expect(
          _eventViewsFor(scenario.chunks),
          _eventViewsFor([scenario.input]),
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
  });
}

enum _GeneratedThinkingTokenKind {
  htmlThink,
  htmlThinking,
  bracketThink,
  bracketThinking,
  fenceThink,
  fenceThinking,
}

enum _GeneratedStreamTextToken {
  word,
  number,
  space,
  newline,
  punctuation,
  markdown,
}

class _GeneratedChatStreamScenario {
  const _GeneratedChatStreamScenario({
    required this.before,
    required this.body,
    required this.after,
    required this.kind,
    required this.chunkSize,
  });

  final List<_GeneratedStreamTextToken> before;
  final List<_GeneratedStreamTextToken> body;
  final List<_GeneratedStreamTextToken> after;
  final _GeneratedThinkingTokenKind kind;
  final int chunkSize;

  String get input =>
      '${before.text}${kind.open}${body.text}${kind.close}${after.text}';

  List<String> get chunks {
    final result = <String>[];
    for (var i = 0; i < input.length; i += chunkSize) {
      final end = i + chunkSize > input.length ? input.length : i + chunkSize;
      result.add(input.substring(i, end));
    }
    return result;
  }

  @override
  String toString() {
    return '_GeneratedChatStreamScenario('
        'input: $input, '
        'kind: $kind, '
        'chunkSize: $chunkSize, '
        'chunks: $chunks)';
  }
}

extension on _GeneratedThinkingTokenKind {
  String get open => switch (this) {
    _GeneratedThinkingTokenKind.htmlThink => '<think>',
    _GeneratedThinkingTokenKind.htmlThinking => '<thinking>',
    _GeneratedThinkingTokenKind.bracketThink => '[think]',
    _GeneratedThinkingTokenKind.bracketThinking => '[thinking]',
    _GeneratedThinkingTokenKind.fenceThink => '```think\n',
    _GeneratedThinkingTokenKind.fenceThinking => '```thinking\n',
  };

  String get close => switch (this) {
    _GeneratedThinkingTokenKind.htmlThink => '</think>',
    _GeneratedThinkingTokenKind.htmlThinking => '</thinking>',
    _GeneratedThinkingTokenKind.bracketThink => '[/think]',
    _GeneratedThinkingTokenKind.bracketThinking => '[/thinking]',
    _GeneratedThinkingTokenKind.fenceThink ||
    _GeneratedThinkingTokenKind.fenceThinking => '```',
  };
}

extension on _GeneratedStreamTextToken {
  String get text => switch (this) {
    _GeneratedStreamTextToken.word => 'alpha',
    _GeneratedStreamTextToken.number => '42',
    _GeneratedStreamTextToken.space => ' ',
    _GeneratedStreamTextToken.newline => '\n',
    _GeneratedStreamTextToken.punctuation => '.,:;!?',
    _GeneratedStreamTextToken.markdown => '- item',
  };
}

extension on List<_GeneratedStreamTextToken> {
  String get text => map((token) => token.text).join();
}

List<({String kind, String text})> _eventViewsFor(List<String> chunks) {
  final parser = ChatStreamParser();
  final views = <({String kind, String text})>[];

  void addEvent(ChatStreamEvent event) {
    final view = switch (event) {
      VisibleAppend(:final text) => (kind: 'visible', text: text),
      ThinkingFinal(:final text) => (kind: 'thinking', text: text),
      _ => (kind: 'unknown', text: ''),
    };

    if (views.isNotEmpty && views.last.kind == view.kind) {
      final previous = views.removeLast();
      views.add((kind: previous.kind, text: '${previous.text}${view.text}'));
    } else {
      views.add(view);
    }
  }

  for (final chunk in chunks) {
    parser.processChunk(chunk).forEach(addEvent);
  }
  parser.finish().forEach(addEvent);
  return views;
}

extension _AnyChatStreamParser on glados.Any {
  glados.Generator<_GeneratedThinkingTokenKind> get _thinkingTokenKind =>
      glados.AnyUtils(this).choose(_GeneratedThinkingTokenKind.values);

  glados.Generator<_GeneratedStreamTextToken> get _streamTextToken =>
      glados.AnyUtils(this).choose(const [
        _GeneratedStreamTextToken.word,
        _GeneratedStreamTextToken.number,
        _GeneratedStreamTextToken.space,
        _GeneratedStreamTextToken.newline,
        _GeneratedStreamTextToken.punctuation,
        _GeneratedStreamTextToken.markdown,
      ]);

  glados.Generator<_GeneratedStreamTextToken> get _visibleStreamTextToken =>
      glados.AnyUtils(this).choose(const [
        _GeneratedStreamTextToken.word,
        _GeneratedStreamTextToken.number,
        _GeneratedStreamTextToken.space,
        _GeneratedStreamTextToken.punctuation,
        _GeneratedStreamTextToken.markdown,
      ]);

  glados.Generator<List<_GeneratedStreamTextToken>> get _streamText =>
      glados.ListAnys(this).listWithLengthInRange(0, 8, _streamTextToken);

  glados.Generator<List<_GeneratedStreamTextToken>> get _visibleStreamText =>
      glados.ListAnys(
        this,
      ).listWithLengthInRange(0, 8, _visibleStreamTextToken);

  glados.Generator<_GeneratedChatStreamScenario>
  get generatedChatStreamScenario => glados.CombinableAny(this).combine5(
    _visibleStreamText,
    _streamText,
    _visibleStreamText,
    _thinkingTokenKind,
    glados.IntAnys(this).intInRange(1, 12),
    (
      List<_GeneratedStreamTextToken> before,
      List<_GeneratedStreamTextToken> body,
      List<_GeneratedStreamTextToken> after,
      _GeneratedThinkingTokenKind kind,
      int chunkSize,
    ) => _GeneratedChatStreamScenario(
      before: before,
      body: body,
      after: after,
      kind: kind,
      chunkSize: chunkSize,
    ),
  );
}
