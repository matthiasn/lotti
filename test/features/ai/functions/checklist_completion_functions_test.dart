import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  test('add_multiple_checklist_items tool requires array of objects', () {
    final tools = ChecklistCompletionFunctions.getTools();
    final tool = tools.firstWhere(
      (t) =>
          t.type == ChatCompletionToolType.function &&
          t.function.name ==
              ChecklistCompletionFunctions.addMultipleChecklistItems,
    );
    final params = tool.function.parameters! as Map<String, Object?>;
    final props = params['properties']! as Map<String, Object?>;
    final items = props['items']! as Map<String, Object?>;
    expect(items['type'], equals('array'));
    expect(items['minItems'], equals(1));
    final itemSchema = items['items']! as Map<String, Object?>;
    expect(itemSchema['type'], equals('object'));
    final itemProps = itemSchema['properties']! as Map<String, Object?>;
    expect(itemProps.containsKey('title'), isTrue);
    expect(itemProps.containsKey('isChecked'), isTrue);
  });

  test('update_checklist_items tool requires array of update objects', () {
    final tools = ChecklistCompletionFunctions.getTools();
    final tool = tools.firstWhere(
      (t) =>
          t.type == ChatCompletionToolType.function &&
          t.function.name == ChecklistCompletionFunctions.updateChecklistItems,
    );
    final params = tool.function.parameters! as Map<String, Object?>;
    final props = params['properties']! as Map<String, Object?>;
    final items = props['items']! as Map<String, Object?>;
    expect(items['type'], equals('array'));
    expect(items['minItems'], equals(1));
    expect(items['maxItems'], equals(20));
    final itemSchema = items['items']! as Map<String, Object?>;
    expect(itemSchema['type'], equals('object'));
    final itemProps = itemSchema['properties']! as Map<String, Object?>;
    expect(itemProps.containsKey('id'), isTrue);
    expect(itemProps.containsKey('isChecked'), isTrue);
    expect(itemProps.containsKey('title'), isTrue);
    // ID is required
    final required = itemSchema['required']! as List<dynamic>;
    expect(required, contains('id'));
  });
}
