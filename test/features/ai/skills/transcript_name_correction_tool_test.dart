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
    test('reads each proposal, trimmed, and skips malformed items', () {
      expect(
        parseTranscriptNameCorrections([
          call({
            'corrections': [
              {'heard': ' Frostbite ', 'term': 'Frostbeak '},
              {'heard': 'Kelson'},
              'not an object',
              {'heard': 3, 'term': 'Wanja'},
            ],
          }),
        ]),
        [(heard: 'Frostbite', term: 'Frostbeak')],
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
    const terms = ['Commander Pip Frostbeak', 'Frida Kjellsen', 'Wanja'];

    test('replaces every whole-word occurrence with the listed spelling', () {
      final result = applyTranscriptNameCorrections(
        'Frostbite called. Frostbites are not Frostbite, said Frida Kelson.',
        const [
          (heard: 'Frostbite', term: 'Frostbeak'),
          (heard: 'Frida Kelson', term: 'Frida Kjellsen'),
        ],
        terms,
      );

      expect(
        result.text,
        'Frostbeak called. Frostbites are not Frostbeak, said Frida Kjellsen.',
      );
      expect(result.corrections, hasLength(2));
    });

    test('a name misheard as several short words becomes the name', () {
      final result = applyTranscriptNameCorrections(
        'We met Kjell Sen today.',
        const [(heard: 'Kjell Sen', term: 'Kjellsen')],
        terms,
      );

      expect(result.text, 'We met Kjellsen today.');
    });

    // The model proposes; the code decides. Each of these would rewrite the
    // transcript in a way the user never asked for.
    for (final (reason, proposal) in [
      (
        'the replacement is not a listed name',
        (heard: 'Door', term: 'Admiral'),
      ),
      (
        'what it replaces is an ordinary lower-case word',
        (heard: 'frostbite', term: 'Frostbeak'),
      ),
      (
        'what it replaces is already a known name',
        (heard: 'Wanja', term: 'Frostbeak'),
      ),
      (
        'what it replaces is not in the transcript',
        (heard: 'Kelson', term: 'Kjellsen'),
      ),
      (
        'what it replaces is a phrase, not a name',
        (heard: 'The Big Blue Door', term: 'Frostbeak'),
      ),
      ('nothing would change', (heard: 'Frostbeak', term: 'Frostbeak')),
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
        const [(heard: 'Waddle', term: 'Wanja')],
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
