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
}
