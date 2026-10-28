import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/mistral_stream_content.dart';

Map<String, dynamic> _thinking(Object? thinking) => {
  'type': 'thinking',
  'thinking': thinking,
};

Map<String, dynamic> _text(String text) => {'type': 'text', 'text': text};

void main() {
  late MistralStreamContent content;

  setUp(() => content = MistralStreamContent());

  group('answers without reasoning', () {
    test('passes a plain string through', () {
      expect(content.next('Hello'), 'Hello');
    });

    test('joins text and string parts of a list', () {
      expect(content.next([_text('Hello '), 'world']), 'Hello world');
    });

    test('is null for no content, an empty list or empty text', () {
      expect(content.next(null), isNull);
      expect(content.next(<Object>[]), isNull);
      expect(content.next(''), isNull);
      expect(content.next([_text('')]), isNull);
    });

    test('skips unknown part types and non-string text', () {
      expect(
        content.next([
          {'type': 'image_url', 'image_url': 'x'},
          {'type': 'text', 'text': 42},
          _text('kept'),
          7,
        ]),
        'kept',
      );
    });

    test('falls back to toString for other content values', () {
      expect(content.next(42), '42');
    });

    test('finishing without an open block adds nothing', () {
      expect(content.next(null, finishing: true), isNull);
    });
  });

  group('thinking', () {
    test('opens one block across deltas and closes it before the answer', () {
      expect(
        content.next([
          _thinking([_text('Step one. ')]),
        ]),
        '<think>Step one. ',
      );
      expect(
        content.next([
          _thinking([_text('Step two.')]),
          _text('Answer'),
        ]),
        'Step two.</think>Answer',
      );
      expect(content.next(' more'), ' more');
    });

    test('a plain string after thinking closes the block', () {
      content.next([_thinking('Hmm.')]);
      expect(content.next('Answer'), '</think>Answer');
    });

    test('tool calls close an open block', () {
      content.next([
        _thinking([_text('Call a tool.')]),
      ]);
      expect(content.next(null, hasToolCalls: true), '</think>');
      expect(content.next(null, hasToolCalls: true), isNull);
    });

    test('a finishing choice closes a block left open', () {
      expect(
        content.next([_thinking('Cut short')], finishing: true),
        '<think>Cut short</think>',
      );
    });

    test('empty or malformed thinking opens no block', () {
      expect(content.next([_thinking(null)]), isNull);
      expect(content.next([_thinking(<Object>[])]), isNull);
      expect(content.next([_thinking(5)]), isNull);
      expect(content.next('Answer'), 'Answer');
    });

    test('reads string parts and skips other parts inside thinking', () {
      expect(
        content.next([
          _thinking([
            'a',
            {'type': 'text', 'text': 1},
            _text('b'),
          ]),
        ]),
        '<think>ab',
      );
    });
  });
}
