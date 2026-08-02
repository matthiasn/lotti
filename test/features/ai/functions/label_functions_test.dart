import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/label_functions.dart';

void main() {
  test('assignTaskLabels constant equals the wire tool name', () {
    // The AI prompt and downstream dispatch key off this exact literal; a
    // rename of the constant value would silently break tool-call routing.
    expect(LabelFunctions.assignTaskLabels, 'assign_task_labels');
  });
}
