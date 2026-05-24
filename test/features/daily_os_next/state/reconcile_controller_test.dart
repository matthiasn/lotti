import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_interface.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';

void main() {
  group('ReconcileController', () {
    late MockDayAgent agent;

    setUp(() {
      agent = MockDayAgent(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );
    });

    ProviderContainer makeContainer({
      DayAgentInterface? override,
      CaptureId aliveFor = const CaptureId('cap_alive'),
    }) {
      final container =
          ProviderContainer(
              overrides: [
                dayAgentProvider.overrideWithValue(override ?? agent),
              ],
            )
            // The reconcile controller is auto-dispose; without a live
            // listener it tears down between `triage` / `breakLink` calls
            // and `state = ...` after the await throws.
            ..listen(reconcileControllerProvider(aliveFor), (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test(
      'build fetches parsed + pending in parallel and merges them',
      () async {
        const id = CaptureId('cap_1');
        final container = makeContainer(aliveFor: id);

        final data = await container.read(
          reconcileControllerProvider(id).future,
        );
        expect(data.parsed, hasLength(4));
        expect(data.pending, hasLength(3));
        expect(data.triageDecisions, isEmpty);
      },
    );

    test('triage updates decisions map for the affected task only', () async {
      const id = CaptureId('cap_2');
      final container = makeContainer(aliveFor: id);

      await container.read(reconcileControllerProvider(id).future);
      await container
          .read(reconcileControllerProvider(id).notifier)
          .triage(taskId: 't_dentist', action: TriageAction.defer);

      final state = container.read(reconcileControllerProvider(id));
      final data = state.value!;
      expect(data.triageDecisions, hasLength(1));
      expect(data.triageDecisions['t_dentist']!.action, TriageAction.defer);
      expect(data.triageDecisions['t_dentist']!.deferredTo, isNotNull);
    });

    test('breakLink replaces the matched parsed item in place', () async {
      const id = CaptureId('cap_3');
      final container = makeContainer(aliveFor: id);

      final initial = await container.read(
        reconcileControllerProvider(id).future,
      );
      final matched = initial.parsed.firstWhere(
        (i) => i.kind == ParsedItemKind.matched,
      );
      expect(matched.matchedTaskId, isNotNull);

      await container
          .read(reconcileControllerProvider(id).notifier)
          .breakLink(matched.id);

      final next = container.read(reconcileControllerProvider(id)).value!;
      final updated = next.parsed.firstWhere((i) => i.id == matched.id);
      expect(updated.kind, ParsedItemKind.newTask);
      expect(updated.matchedTaskId, isNull);
      // Other parsed items are untouched.
      expect(next.parsed.length, initial.parsed.length);
    });
  });
}
