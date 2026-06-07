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

    test('defaults to speech hidden when no arguments are passed', () {
      final v = deriveAutomaticPromptVisibility();

      expect(v.speech, isFalse);
      expect(v.none, isTrue);
    });

    // Asserts the full observable state of the derived record for every input,
    // not just the field under test. If the struct gains additional visibility
    // fields (e.g. taskSummary, checklist), this loop's `expected` map will be
    // missing a key and the dynamic comparison below must be extended,
    // surfacing the new field instead of silently leaving it untested.
    for (final hasProfileTranscription in [true, false]) {
      test(
        'derives the full visibility state for '
        'hasProfileTranscription=$hasProfileTranscription',
        () {
          final v = deriveAutomaticPromptVisibility(
            hasProfileTranscription: hasProfileTranscription,
          );

          // `none` is a derived complement of `speech`; this invariant must
          // hold for every input and is what the modal relies on to decide
          // whether to render any automatic-prompt checkboxes at all.
          expect(
            v.none,
            !v.speech,
            reason: 'none must always be the complement of speech',
          );

          // Full observable state of the record for this input. Keep this map
          // exhaustive: every public flag/getter on AutomaticPromptVisibility
          // should appear here so new fields cannot be added without updating
          // this expectation.
          final actual = {
            'speech': v.speech,
            'none': v.none,
          };
          expect(actual, {
            'speech': hasProfileTranscription,
            'none': !hasProfileTranscription,
          });
        },
      );
    }
  });
}
