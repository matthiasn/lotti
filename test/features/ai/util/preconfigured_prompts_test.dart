import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  test('Checklist updates prompt includes bracket prohibition', () {
    final prompt = checklistUpdatesPrompt.systemMessage;
    expect(prompt, contains('Never put square‑bracketed arrays'));
    expect(prompt, contains('actionItemDescription'));
  });

  test('Checklist updates prompt user message includes Assigned Labels section', () {
    final user = checklistUpdatesPrompt.userMessage;
    expect(user, contains('Assigned Labels'));
    expect(user, contains('{{assigned_labels}}'));
  });
}
