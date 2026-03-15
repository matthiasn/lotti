import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';

void main() {
  group('deriveAutomaticPromptVisibility', () {
    test('speech visible when hasProfileTranscription is true', () {
      final v = deriveAutomaticPromptVisibility(
        hasProfileTranscription: true,
      );

      expect(v.speech, isTrue);
      expect(v.none, isFalse);
    });

    test(
      'speech hidden when hasProfileTranscription is false',
      () {
        final v = deriveAutomaticPromptVisibility(
          // ignore: avoid_redundant_argument_values
          hasProfileTranscription: false,
        );

        expect(v.speech, isFalse);
        expect(v.none, isTrue);
      },
    );
  });
}
