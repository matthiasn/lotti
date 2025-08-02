import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('Task Summary and Checklist Updates Separation', () {
    test('task summary prompt does not include function call instructions', () {
      // Task summary should focus only on generating text summaries
      expect(
        taskSummaryPrompt.systemMessage,
        isNot(contains('function')),
      );
      expect(
        taskSummaryPrompt.systemMessage,
        isNot(contains('set_task_language')),
      );
      expect(
        taskSummaryPrompt.userMessage,
        isNot(contains('function')),
      );

      // Should still handle language preference for output
      expect(
        taskSummaryPrompt.systemMessage,
        contains('Generate the summary in the language'),
      );
      expect(
        taskSummaryPrompt.userMessage,
        contains('Generate the summary in the language specified'),
      );
    });

    test('checklist updates prompt only handles function calls', () {
      // Check that checklist updates is function-only
      expect(
        checklistUpdatesPrompt.systemMessage,
        contains('ONLY processes task updates through function calls'),
      );
      expect(
        checklistUpdatesPrompt.systemMessage,
        contains('You should NOT generate any text response'),
      );
      expect(
        checklistUpdatesPrompt.systemMessage,
        contains('ONLY output function calls, no other text'),
      );
    });

    test('checklist updates prompt includes language detection function', () {
      expect(
        checklistUpdatesPrompt.systemMessage,
        contains('set_task_language'),
      );
      expect(
        checklistUpdatesPrompt.systemMessage,
        contains('ONLY use if languageCode is null in the task data'),
      );
    });

    test('checklist updates prompt includes checklist completion functions',
        () {
      expect(
        checklistUpdatesPrompt.systemMessage,
        contains('suggest_checklist_completion'),
      );
      expect(
        checklistUpdatesPrompt.systemMessage,
        contains('add_checklist_item'),
      );
    });

    test('prompts have clear separation of concerns', () {
      // Task summary focuses on text generation
      expect(
        taskSummaryPrompt.description,
        contains('comprehensive summary'),
      );

      // Checklist updates focuses on function calls
      expect(
        checklistUpdatesPrompt.description,
        contains('Process task updates through function calls'),
      );

      // They are distinct prompts
      expect(taskSummaryPrompt.name, equals('Task Summary'));
      expect(checklistUpdatesPrompt.name, equals('Checklist Updates'));
    });
  });
}
