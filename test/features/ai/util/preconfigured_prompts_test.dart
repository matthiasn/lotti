import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('Task Summary Prompt - Goal Section', () {
    test('includes Goal section instruction', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('**Goal**'));
      expect(user, contains('desired outcome'));
      expect(user, contains('essential purpose'));
    });

    test('specifies Goal should be succinct', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('1-3 sentences'));
    });

    test('includes Goal example format', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('**Goal:**'));
    });

    test('Goal section comes after TLDR in instructions', () {
      final user = taskSummaryPrompt.userMessage;
      final tldrExampleIndex = user.indexOf('Example TLDR format:');
      final goalInstructionIndex =
          user.indexOf('After the TLDR, include a **Goal**');
      expect(goalInstructionIndex, greaterThan(tldrExampleIndex));
    });

    test('Goal section comes before Achieved results in example', () {
      final user = taskSummaryPrompt.userMessage;
      final goalExampleIndex = user.indexOf('**Goal:** [1-3 sentence');
      final achievedIndex = user.indexOf('**Achieved results:**');
      expect(goalExampleIndex, greaterThan(-1));
      expect(achievedIndex, greaterThan(goalExampleIndex));
    });
  });

  group('Task Summary Prompt - Link Extraction', () {
    test('includes Links section instruction', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('**Links** section'));
      expect(user, contains('**Links:**'));
    });

    test('instructs to scan log entries for URLs', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('Scan ALL log entries'));
      expect(user, contains('URLs'));
      expect(user, contains('http://'));
      expect(user, contains('https://'));
    });

    test('instructs Markdown link format', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('[Succinct Title](URL)'));
      expect(user, contains('short, succinct title'));
    });

    test('instructs to extract unique URLs', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('unique URL'));
    });

    test('instructs to omit Links section when no links found', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('no links are found'));
      expect(user, contains('omit the Links section'));
    });

    test('includes example links section with various URL types', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('[Flutter Documentation]'));
      expect(user, contains('docs.flutter.dev'));
      expect(user, contains('[Linear: APP-123]'));
      expect(user, contains('linear.app'));
      expect(user, contains('[Lotti PR #456]'));
      expect(user, contains('[GitHub Issue'));
      expect(user, contains('github.com'));
      expect(user, contains('[Stack Overflow Solution]'));
      expect(user, contains('stackoverflow.com'));
    });

    test('includes disclaimer about example URLs', () {
      final user = taskSummaryPrompt.userMessage;
      expect(user, contains('format examples only'));
      expect(user, contains('never copy these URLs'));
      expect(user, contains('only use actual URLs found in the task'));
    });
  });

  test('Checklist updates prompt instructs array-of-objects format', () {
    final prompt = checklistUpdatesPrompt.systemMessage;
    expect(prompt, contains('add_multiple_checklist_items'));
    expect(prompt, contains('JSON array of objects'));
    expect(prompt, isNot(contains('actionItemDescription')));
  });

  test('Checklist updates prompt user message includes Assigned Labels section',
      () {
    final user = checklistUpdatesPrompt.userMessage;
    expect(user, contains('Assigned Labels'));
    expect(user, contains('{{assigned_labels}}'));
  });

  test('Checklist updates prompt includes entry-scoped directive guidance', () {
    final sys = checklistUpdatesPrompt.systemMessage;
    expect(sys, contains('ENTRY-SCOPED DIRECTIVES'));
    expect(sys, contains("Don't consider this for checklist items"));
    expect(sys, contains('Single checklist item'));

    final user = checklistUpdatesPrompt.userMessage;
    expect(user, contains('Directive reminder'));
    expect(user, contains('Ignore for checklist'));
    expect(user, contains('The rest is an implementation plan'));
  });

  test('Checklist updates prompt includes update_checklist_items guidance', () {
    final sys = checklistUpdatesPrompt.systemMessage;
    expect(sys, contains('update_checklist_items'));
    expect(sys, contains('Update existing checklist items by ID'));
    expect(sys, contains('isChecked'));
    expect(sys, contains('title'));
    // Check for reactive behavior guidance
    expect(sys, contains('REACTIVE'));
    // Check for title correction examples (multiple common cases)
    expect(sys, contains('macOS'));
    expect(sys, contains('iPhone'));
    expect(sys, contains('GitHub'));
    expect(sys, contains('TestFlight'));
    // Check for error guidance
    expect(sys, contains('invalid'));
    expect(sys, contains('skipped'));
  });

  test('Checklist updates prompt includes negative examples', () {
    final sys = checklistUpdatesPrompt.systemMessage;
    // Check for DON'T examples to prevent misuse
    expect(sys, contains("Examples (DON'T)"));
    expect(sys, contains('proactively fix'));
    expect(sys, contains('INVALID'));
  });
}
