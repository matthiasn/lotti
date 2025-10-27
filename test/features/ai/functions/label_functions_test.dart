import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/label_functions.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  test('assign_task_labels tool is defined with correct schema', () {
    final tools = LabelFunctions.getTools();
    expect(tools, isNotEmpty);
    final tool = tools.first;
    expect(tool.type, ChatCompletionToolType.function);
    expect(tool.function.name, LabelFunctions.assignTaskLabels);

    // Validate parameters schema
    final params = tool.function.parameters!;
    expect(params['type'], 'object');
    final props = params['properties'] as Map<String, dynamic>;
    final labelIds = props['labelIds'] as Map<String, dynamic>;
    expect(labelIds['type'], 'array');
    expect((params['required'] as List).contains('labelIds'), isTrue);
  });
}
