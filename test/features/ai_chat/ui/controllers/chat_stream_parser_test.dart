import 'package:flutter_test/flutter_test.dart';
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
          (e3.single as VisibleAppend).text.startsWith('\nparagraph'), isTrue);
      expect((e3.single as VisibleAppend).text.startsWith('\n\n'), isFalse);
    });

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

    test('unterminated thinking is flushed on finish', () {
      final p = ChatStreamParser();
      final e1 = p.processChunk('<thinking>incomplete');
      expect(e1, isEmpty);
      final flushed = p.finish();
      expect(flushed.single, isA<ThinkingFinal>());
      expect((flushed.single as ThinkingFinal).text, 'incomplete');
    });

    test('whitespace-only unterminated thinking is not flushed', () {
      final p = ChatStreamParser();
      // ignore: cascade_invocations
      p.processChunk('<thinking>   ');
      final flushed = p.finish();
      expect(flushed, isEmpty);
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

    test('nested thinking emits first closed block content (non-nested parser)',
        () {
      final p = ChatStreamParser();
      final e = p.processChunk(
          '<thinking>outer <thinking>inner</thinking> end</thinking>');
      expect(e.isNotEmpty, isTrue);
      final tf = e.whereType<ThinkingFinal>().first;
      final text = tf.text;
      expect(text.contains('outer'), isTrue);
      expect(text.contains('inner'), isTrue);
      // Parser is not nested-aware; it may not include trailing 'end'.
    });
  });
}
