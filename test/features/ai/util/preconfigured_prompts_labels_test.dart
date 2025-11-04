import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  test('Checklist updates prompt includes Phase 2 label rules', () {
    final sys = checklistUpdatesPrompt.systemMessage;
    expect(sys, contains('do NOT call assign_task_labels'));
    expect(sys, contains('highest-confidence'));
    expect(sys, contains('omit low'));
    expect(sys, contains('Cap to at most 3 labels'));
  });
}
