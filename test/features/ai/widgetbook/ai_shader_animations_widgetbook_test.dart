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

  group('applyVoiceDbfsEnvelope', () {
    test('uses a 20ms sampling interval for recorder updates', () {
      expect(
        voiceRecorderAmplitudeInterval,
        const Duration(milliseconds: 20),
      );
    });

    test('applies louder values immediately for fast attack', () {
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -62,
        targetDbfs: -18,
        floorDbfs: -80,
      );

      expect(next, -18);
    });

    test('limits quieter values with a slower release', () {
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -18,
        targetDbfs: -80,
        floorDbfs: -80,
      );

      expect(next, closeTo(-19.28, 0.001));
    });

    test('does not release below the target value', () {
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -79.8,
        targetDbfs: -80,
        floorDbfs: -80,
      );

      expect(next, -80);
    });
  });
}
