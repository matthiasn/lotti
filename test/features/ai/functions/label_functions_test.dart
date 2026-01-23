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

    // Back-compat property remains
    final labelIds = props['labelIds'] as Map<String, dynamic>;
    expect(labelIds['type'], 'array');
    expect(labelIds['items'], isA<Map<String, dynamic>>());

    // New preferred property exists
    final labelsProp = props['labels'] as Map<String, dynamic>;
    expect(labelsProp['type'], 'array');
    final labelsItems = labelsProp['items'] as Map<String, dynamic>;
    final itemProps = labelsItems['properties'] as Map<String, dynamic>;
    expect((itemProps['id'] as Map<String, dynamic>)['type'], 'string');
    final confidence = itemProps['confidence'] as Map<String, dynamic>;
    expect(confidence['type'], 'string');
    expect(confidence['enum'],
        containsAll(['low', 'medium', 'high', 'very_high']));

    // oneOf accepts either new or legacy
    final oneOf = params['oneOf'] as List<dynamic>;
    expect(oneOf.length, 2);
    final r0 = (oneOf[0] as Map<String, dynamic>)['required'] as List<dynamic>;
    final r1 = (oneOf[1] as Map<String, dynamic>)['required'] as List<dynamic>;
    expect(r0.contains('labels') || r1.contains('labels'), isTrue);
    expect(r0.contains('labelIds') || r1.contains('labelIds'), isTrue);
  });
}
