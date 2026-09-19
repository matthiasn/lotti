import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/skills/transcript_name_correction_tool.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  ChatCompletionMessageToolCall call(
    Object? arguments, {
    String name = transcriptNameCorrectionToolName,
  }) => ChatCompletionMessageToolCall(
    id: 'call-1',
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: arguments is String ? arguments : jsonEncode(arguments),
    ),
  );

  group('parseTranscriptNameCorrections', () {
    test('reads each proposal, trimmed, with its quote, and skips malformed '
        'items', () {
      expect(
        parseTranscriptNameCorrections([
          call({
            'corrections': [
              {
                'heard': ' Frostbite ',
                'term': 'Frostbeak ',
                'context': ' Frostbite wants ',
              },
              {'heard': 'Kelson', 'term': 'Kjellsen', 'context': '  '},
              {'heard': 'Kelson'},
              'not an object',
              {'heard': 3, 'term': 'Wanja'},
            ],
          }),
        ]),
        [
          (heard: 'Frostbite', term: 'Frostbeak', context: 'Frostbite wants'),
          (heard: 'Kelson', term: 'Kjellsen', context: null),
        ],
      );
    });

    test('is empty — no correction, never an error — for a missing, '
        'foreign or malformed call', () {
      expect(parseTranscriptNameCorrections(const []), isEmpty);
      expect(
        parseTranscriptNameCorrections([
          call({'corrections': <Object>[]}, name: 'publish_entry_summary'),
        ]),
        isEmpty,
      );
      expect(parseTranscriptNameCorrections([call('{not json')]), isEmpty);
      expect(parseTranscriptNameCorrections([call('[1]')]), isEmpty);
      expect(
        parseTranscriptNameCorrections([
          call({'corrections': 'none'}),
        ]),
        isEmpty,
      );
    });
  });

  group('applyTranscriptNameCorrections', () {
    const terms = ['Commander Pip Frostbeak', 'Frida Kjellsen', 'Wanja', 'Mae'];

    test('replaces the occurrence its quote names, and only that one', () {
      // CodeRabbit review on #4374: one proposal must not rewrite an
      // occurrence the model never looked at.
      final result = applyTranscriptNameCorrections(
        'May called me in May.',
        const [(heard: 'May', term: 'Mae', context: 'May called')],
        terms,
      );

      expect(result.text, 'Mae called me in May.');
      expect(result.corrections, [(heard: 'May', term: 'Mae')]);
    });

    test('a quote per occurrence corrects each of them', () {
      final result = applyTranscriptNameCorrections(
        'Frostbite called. Later Frostbite wrote, said Frida Kelson.',
        const [
          (heard: 'Frostbite', term: 'Frostbeak', context: 'Frostbite called'),
          (heard: 'Frostbite', term: 'Frostbeak', context: 'Later Frostbite'),
          (
            heard: 'Frida Kelson',
            term: 'Frida Kjellsen',
            context: 'said Frida Kelson',
          ),
        ],
        terms,
      );

      expect(
        result.text,
        'Frostbeak called. Later Frostbeak wrote, said Frida Kjellsen.',
      );
      expect(result.corrections, hasLength(3));
    });

    test('without a quote, a word that occurs once is corrected and one '
        'that repeats is left alone', () {
      expect(
        applyTranscriptNameCorrections(
          'We met Kjell Sen today.',
          const [(heard: 'Kjell Sen', term: 'Kjellsen', context: null)],
          terms,
        ).text,
        'We met Kjellsen today.',
      );
      const repeated = 'May called me in May.';
      expect(
        applyTranscriptNameCorrections(
          repeated,
          const [(heard: 'May', term: 'Mae', context: null)],
          terms,
        ).text,
        repeated,
      );
    });

    // The model proposes; the code decides. Each of these would rewrite the
    // transcript in a way the user never asked for.
    for (final (reason, proposal) in [
      (
        'the replacement is not a listed name',
        (heard: 'Door', term: 'Admiral', context: 'Blue Door'),
      ),
      (
        'what it replaces is an ordinary lower-case word',
        (heard: 'frostbite', term: 'Frostbeak', context: 'saw frostbite'),
      ),
      (
        'what it replaces is already a known name',
        (heard: 'Wanja', term: 'Frostbeak', context: 'Wanja saw'),
      ),
      (
        'what it replaces is not in the transcript',
        (heard: 'Kelson', term: 'Kjellsen', context: null),
      ),
      (
        'its quote is not in the transcript',
        (heard: 'Door', term: 'Mae', context: 'Red Door'),
      ),
      (
        'its quote does not contain it',
        (heard: 'Door', term: 'Mae', context: 'The Big Blue'),
      ),
      (
        'what it replaces is a phrase, not a name',
        (
          heard: 'The Big Blue Door',
          term: 'Mae',
          context: 'at The Big Blue Door',
        ),
      ),
      (
        'nothing would change',
        (heard: 'Frostbeak', term: 'Frostbeak', context: 'Pip Frostbeak'),
      ),
    ]) {
      test('is refused when $reason', () {
        const text =
            'Wanja saw frostbite at The Big Blue Door with Pip Frostbeak.';
        final result = applyTranscriptNameCorrections(text, [proposal], terms);

        expect(result.text, text);
        expect(result.corrections, isEmpty);
      });
    }

    test('matches whole words only, never inside another word', () {
      final result = applyTranscriptNameCorrections(
        'Waddleton and Waddle',
        const [(heard: 'Waddle', term: 'Wanja', context: 'and Waddle')],
        terms,
      );

      expect(result.text, 'Waddleton and Wanja');
    });
  });

  test('the prompt lists the names and carries the transcript', () {
    final messages = transcriptNameCorrectionMessages(
      transcript: 'Vanja traf Frostbite.',
      terms: const ['Wanja', 'Commander Pip Frostbeak'],
    );

    expect(messages.user, contains('- Wanja\n- Commander Pip Frostbeak'));
    expect(messages.user, endsWith('Transcript:\nVanja traf Frostbite.'));
    expect(messages.system, contains('misheard names'));
  });
}
