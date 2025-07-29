import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('Task Summary Language Generation', () {
    test('prompt instructs AI to continue generating after function calls', () {
      // Check system message
      expect(
        taskSummaryPrompt.systemMessage,
        contains(
            'You MUST generate BOTH function calls AND the complete task summary in ONE response'),
      );
      expect(
        taskSummaryPrompt.systemMessage,
        contains(
            'DO NOT stop after calling functions - continue with the full summary immediately'),
      );

      // Check user message
      expect(
        taskSummaryPrompt.userMessage,
        contains(
            'You MUST generate the ENTIRE task summary regardless of any function calls you make'),
      );
      expect(
        taskSummaryPrompt.userMessage,
        contains(
            'Function calls (like set_task_language) are side effects - you must still provide the full summary!'),
      );
    });

    test('prompt handles existing language preference correctly', () {
      expect(
        taskSummaryPrompt.systemMessage,
        contains('ONLY use if languageCode is null in the task data'),
      );
    });
  });
}
