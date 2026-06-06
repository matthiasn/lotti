import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  group('applyVoiceDbfsEnvelope — properties', () {
    // dBFS triples sampled across the full meter range, plus elapsed/release
    // knobs, so boundary conditions (equal values, exact floor) are hit.
    glados.Glados3<int, int, int>(
      glados.any.intInRange(-8000, 1),
      glados.any.intInRange(-8000, 1),
      glados.any.intInRange(-8000, -100),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'result always stays within [floor, 0] and never amplifies during '
      'release',
      (currentCenti, targetCenti, floorCenti) {
        final current = currentCenti / 100;
        final target = targetCenti / 100;
        final floor = floorCenti / 100;

        final result = applyVoiceDbfsEnvelope(
          currentDbfs: current,
          targetDbfs: target,
          floorDbfs: floor,
        );

        // Bounded to the meter range.
        expect(result, greaterThanOrEqualTo(floor));
        expect(result, lessThanOrEqualTo(0));

        final clampedCurrent = current.clamp(floor, 0.0);
        final clampedTarget = target.clamp(floor, 0.0);
        if (clampedTarget >= clampedCurrent) {
          // Instant attack: jumps straight to the (clamped) target.
          expect(result, clampedTarget);
        } else {
          // Gradual release: moves down, but never past the target.
          expect(result, lessThanOrEqualTo(clampedCurrent));
          expect(result, greaterThanOrEqualTo(clampedTarget));
        }
      },
      tags: 'glados',
    );
  });
}
