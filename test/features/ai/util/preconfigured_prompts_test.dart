import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
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
}
