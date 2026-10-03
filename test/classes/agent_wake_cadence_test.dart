import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/agent_wake_cadence.dart';

extension _AnyCadence on glados.Any {
  glados.Generator<AgentWakeCadence?> get optionalCadence =>
      glados.AnyUtils(this).choose(<AgentWakeCadence?>[
        null,
        ...AgentWakeCadence.values,
      ]);
}

void main() {
  group('AgentWakeCadence', () {
    test('round-trips through its name; unknown names read as unset', () {
      for (final cadence in AgentWakeCadence.values) {
        expect(AgentWakeCadence.fromName(cadence.name), cadence);
      }
      expect(AgentWakeCadence.fromName('everyFortnight'), isNull);
      expect(AgentWakeCadence.fromName(null), isNull);
    });

    test('windows: two minutes live, an hour hourly, none for recordings', () {
      expect(AgentWakeCadence.live.coalescingWindow, liveCoalescingWindow);
      expect(liveCoalescingWindow, const Duration(minutes: 2));
      expect(
        AgentWakeCadence.hourly.coalescingWindow,
        const Duration(hours: 1),
      );
      expect(AgentWakeCadence.recordingsOnly.coalescingWindow, isNull);
    });

    test('only "recordings only" ignores finished work and images', () {
      for (final cadence in AgentWakeCadence.values) {
        final reacts = cadence != AgentWakeCadence.recordingsOnly;
        expect(cadence.flushesOnFinishedWork, reacts, reason: cadence.name);
        expect(cadence.respondsToImageAnalysis, reacts, reason: cadence.name);
      }
    });

    test('an image window is shorter than every coalescing window', () {
      for (final cadence in AgentWakeCadence.values) {
        final window = cadence.coalescingWindow;
        if (window != null) expect(imageAnalysisWindow < window, isTrue);
      }
    });
  });

  group('resolveAgentWakeCadence', () {
    glados.Glados3(
      glados.any.optionalCadence,
      glados.any.optionalCadence,
      glados.any.optionalCadence,
    ).test(
      'the most specific level that is set wins, else hourly',
      (task, category, global) {
        expect(
          resolveAgentWakeCadence(
            task: task,
            category: category,
            global: global,
          ),
          task ?? category ?? global ?? AgentWakeCadence.hourly,
        );
      },
      tags: 'glados',
    );

    test('a task choice overrides a category that chose differently', () {
      expect(
        resolveAgentWakeCadence(
          task: AgentWakeCadence.live,
          category: AgentWakeCadence.recordingsOnly,
          global: AgentWakeCadence.hourly,
        ),
        AgentWakeCadence.live,
      );
    });
  });
}
