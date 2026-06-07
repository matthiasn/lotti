import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/widgetbook/ai_shader_animations_widgetbook.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  group('buildAiWidgetbookFolder', () {
    test('exposes the shader animation testbench use cases', () {
      final folder = buildAiWidgetbookFolder();

      // Guard the force-unwrap: an empty folder would otherwise throw an
      // opaque null-check error instead of a readable expectation failure.
      expect(folder.children, isNotNull);
      expect(folder.children, hasLength(1));
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

    test('uses a 64 dB/s default release rate', () {
      // Documents the intentional default release slope so an accidental
      // change to the constant fails loudly rather than silently shifting
      // every release-step assertion below.
      expect(voiceRecorderReleaseDbPerSecond, 64.0);
    });

    test('applies louder values immediately for fast attack', () {
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -62,
        targetDbfs: -18,
        floorDbfs: -80,
      );

      expect(next, closeTo(-18.0, 0.001));
    });

    test('limits quieter values with a slower release', () {
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -18,
        targetDbfs: -80,
        floorDbfs: -80,
      );

      // releaseStep = 64 dB/s * 20ms = 1.28 dB → -18 - 1.28 = -19.28.
      expect(next, closeTo(-19.28, 0.001));
    });

    test('does not release below the target value', () {
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -79.8,
        targetDbfs: -80,
        floorDbfs: -80,
      );

      expect(next, closeTo(-80.0, 0.001));
    });

    test('returns the target when the release step lands exactly on it', () {
      // releaseStep = 64 dB/s * 20ms = 1.28 dB, so current - step == target.
      // math.max(target, current - step) must collapse to that shared value.
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -18,
        targetDbfs: -19.28,
        floorDbfs: -80,
      );

      expect(next, closeTo(-19.28, 0.001));
    });

    test('scales the release step with a shorter elapsed interval', () {
      // Half the default interval (10ms) → half the step: 64 * 0.01 = 0.64 dB,
      // so -18 - 0.64 = -18.64 instead of the 20ms result of -19.28.
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -18,
        targetDbfs: -80,
        floorDbfs: -80,
        elapsed: const Duration(milliseconds: 10),
      );

      expect(next, closeTo(-18.64, 0.001));
    });

    test('scales the release step with a custom release rate', () {
      // Half the default rate (32 dB/s) over the default 20ms interval →
      // 32 * 0.02 = 0.64 dB step, matching the 10ms / 64 dB/s case.
      final next = applyVoiceDbfsEnvelope(
        currentDbfs: -18,
        targetDbfs: -80,
        floorDbfs: -80,
        releaseDbPerSecond: 32,
      );

      expect(next, closeTo(-18.64, 0.001));
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
