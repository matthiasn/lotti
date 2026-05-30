import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/widgetbook/ai_shader_animations_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  group('buildAiWidgetbookFolder', () {
    test('exposes the shader animation testbench use cases', () {
      final folder = buildAiWidgetbookFolder();
      final component = folder.children!.single as WidgetbookComponent;

      expect(folder.name, 'AI');
      expect(component.name, 'State shader animations');
      expect(component.useCases.map((useCase) => useCase.name), [
        'Voice playground',
        'Voice route matrix',
        'Thinking playground',
        'Thinking route matrix',
        'Action bar study',
      ]);
    });
  });
}
