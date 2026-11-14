import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/helpers/generated_prompt_summary.dart';

void main() {
  group('generatedPromptSummary', () {
    test('is the Summary section, without the Prompt that follows', () {
      expect(
        generatedPromptSummary(
          '## Summary\n\nCheck the crosswind limits.\n\n'
          '## Prompt\n\nYou are a launch engineer…',
        ),
        'Check the crosswind limits.',
      );
    });

    test('keeps a summary of several lines whole', () {
      expect(
        generatedPromptSummary(
          '## Summary\nFirst line.\nSecond line.\n\n## Prompt\nBody',
        ),
        'First line.\nSecond line.',
      );
    });

    test('reads the headings whatever their case or spacing', () {
      expect(
        generatedPromptSummary('##summary\nShort.\n##  PROMPT\nBody'),
        'Short.',
      );
    });

    test('with no Prompt section, runs to the end', () {
      expect(
        generatedPromptSummary('## Summary\nOnly a summary.  '),
        'Only a summary.',
      );
    });

    test('a response that did not follow the format gives its first line', () {
      expect(
        generatedPromptSummary('  Just fix the gate.  \nThen paint it.'),
        'Just fix the gate.',
      );
      expect(generatedPromptSummary(''), '');
    });
  });

  test('the section pattern captures the summary alone', () {
    final match = generatedPromptSummarySection.firstMatch(
      '## Summary\nA.\n## Prompt\nB.',
    );
    expect(match!.group(1)!.trim(), 'A.');
  });
}
