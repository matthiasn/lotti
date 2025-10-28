import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  test('add_multiple_checklist_items tool prefers array via oneOf', () {
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
    expect(items.containsKey('oneOf'), isTrue);
    final oneOfRaw = items['oneOf']! as List;
    final oneOf = oneOfRaw.cast<Map<String, Object?>>();
    expect(oneOf.length, greaterThanOrEqualTo(2));
    // First option should be array
    final first = oneOf.first;
    expect(first['type'], equals('array'));
  });
}
