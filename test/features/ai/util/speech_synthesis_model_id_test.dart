import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/util/speech_synthesis_model_id.dart';

void main() {
  test('tells Voxtral TTS from Voxtral transcription by the tts segment', () {
    const cases = {
      'voxtral-mini-tts-3-0': true,
      'voxtral-mini-tts-2603': true,
      'Voxtral-Mini-TTS-latest': true,
      'mistralai/Voxtral-4B-TTS-2603': true,
      'eleven_multilingual_tts': true,
      'tts': true,
      'voxtral-mini-latest': false,
      'voxtral-mini-transcribe-2602': false,
      'voxtral-ttsx-1': false,
      'gpt-4o-transcribe': false,
      '': false,
    };
    for (final MapEntry(key: id, value: expected) in cases.entries) {
      expect(isSpeechSynthesisModelId(id), expected, reason: '"$id"');
    }
  });

  // Property: a `tts` segment anywhere marks a speech model, whatever
  // letters-and-digits segments surround it.
  glados.Glados2(glados.any.letterOrDigits, glados.any.letterOrDigits).test(
    'a tts segment is found wherever it sits',
    (before, after) {
      expect(isSpeechSynthesisModelId('$before-tts-$after'), isTrue);
      expect(
        isSpeechSynthesisModelId('$before$after'),
        '$before$after'.toLowerCase() == 'tts',
      );
    },
    tags: 'glados',
  );
}
