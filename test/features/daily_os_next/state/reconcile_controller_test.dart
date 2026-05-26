import 'dart:async';

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

    ReconcileParams paramsFor(CaptureId id, {DateTime? dayDate}) =>
        ReconcileParams(
          captureId: id,
          dayDate: dayDate ?? DateTime(2026, 5, 25),
        );

    ProviderContainer makeContainer({
      DayAgentInterface? override,
      ReconcileParams? aliveFor,
      Stream<Set<String>>? updates,
    }) {
      final aliveParams = aliveFor ?? paramsFor(const CaptureId('cap_alive'));
      final container =
          ProviderContainer(
              overrides: [
                dayAgentProvider.overrideWithValue(override ?? agent),
                reconcileCaptureUpdateProvider.overrideWith(
                  (ref, captureId) =>
                      updates ?? const Stream<Set<String>>.empty(),
                ),
              ],
            )
            // The reconcile controller is auto-dispose; without a live
            // listener it tears down between `triage` / `breakLink` calls
            // and `state = ...` after the await throws.
            ..listen(reconcileControllerProvider(aliveParams), (_, _) {});
      addTearDown(container.dispose);
      return container;
    }

    test(
      'build fetches parsed + pending in parallel and merges them',
      () async {
        const id = CaptureId('cap_1');
        final params = paramsFor(id);
        final container = makeContainer(aliveFor: params);

        final data = await container.read(
          reconcileControllerProvider(params).future,
        );
        expect(data.parsed, hasLength(4));
        expect(data.pending, hasLength(3));
        expect(data.triageDecisions, isEmpty);
      },
    );

    test(
      'build requests pending decisions for the selected plan date',
      () async {
        const id = CaptureId('cap_tomorrow');
        final dateRecordingAgent = _DateRecordingDayAgent();
        final params = paramsFor(id, dayDate: DateTime(2026, 5, 27, 14, 30));
        final container = makeContainer(
          override: dateRecordingAgent,
          aliveFor: params,
        );

        await container.read(reconcileControllerProvider(params).future);

        expect(dateRecordingAgent.pendingDate, DateTime(2026, 5, 27));
      },
    );

    test('triage updates decisions map for the affected task only', () async {
      const id = CaptureId('cap_2');
      final params = paramsFor(id);
      final container = makeContainer(aliveFor: params);

      await container.read(reconcileControllerProvider(params).future);
      await container
          .read(reconcileControllerProvider(params).notifier)
          .triage(taskId: 't_dentist', action: TriageAction.defer);

      final state = container.read(reconcileControllerProvider(params));
      final data = state.value!;
      expect(data.triageDecisions, hasLength(1));
      expect(data.triageDecisions['t_dentist']!.action, TriageAction.defer);
      expect(data.triageDecisions['t_dentist']!.deferredTo, isNotNull);
    });

    test(
      're-reads parsed items when the capture emits an update',
      () async {
        const id = CaptureId('cap_refresh');
        final params = paramsFor(id);
        final updates = StreamController<Set<String>>.broadcast();
        addTearDown(updates.close);
        final refreshingAgent = _RefreshingDayAgent();
        final container = makeContainer(
          override: refreshingAgent,
          aliveFor: params,
          updates: updates.stream,
        );

        final initial = await container.read(
          reconcileControllerProvider(params).future,
        );
        expect(initial.parsed, isEmpty);

        await container
            .read(reconcileControllerProvider(params).notifier)
            .triage(taskId: 't_dentist', action: TriageAction.defer);
        updates.add({id.value});
        await pumpEventQueue();

        final refreshed = await container.read(
          reconcileControllerProvider(params).future,
        );
        expect(refreshingAgent.parseCalls, greaterThanOrEqualTo(2));
        expect(refreshed.parsed.single.title, 'Review outstanding invoices');
        expect(
          refreshed.triageDecisions['t_dentist']?.action,
          TriageAction.defer,
        );
      },
    );

    test('breakLink replaces the matched parsed item in place', () async {
      const id = CaptureId('cap_3');
      final params = paramsFor(id);
      final container = makeContainer(aliveFor: params);

      final initial = await container.read(
        reconcileControllerProvider(params).future,
      );
      final matched = initial.parsed.firstWhere(
        (i) => i.kind == ParsedItemKind.matched,
      );
      expect(matched.matchedTaskId, isNotNull);

      await container
          .read(reconcileControllerProvider(params).notifier)
          .breakLink(matched.id);

      final next = container.read(reconcileControllerProvider(params)).value!;
      final updated = next.parsed.firstWhere((i) => i.id == matched.id);
      expect(updated.kind, ParsedItemKind.newTask);
      expect(updated.matchedTaskId, isNull);
      // Other parsed items are untouched.
      expect(next.parsed.length, initial.parsed.length);
    });
  });
}

class _DateRecordingDayAgent extends MockDayAgent {
  _DateRecordingDayAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  DateTime? pendingDate;

  @override
  Future<List<PendingItem>> surfacePendingDecisions({
    DateTime? forDate,
  }) async {
    pendingDate = forDate;
    return super.surfacePendingDecisions(forDate: forDate);
  }
}

class _RefreshingDayAgent extends MockDayAgent {
  _RefreshingDayAgent()
    : super(
        parseLatency: Duration.zero,
        pendingLatency: Duration.zero,
        triageLatency: Duration.zero,
        clock: () => DateTime(2026, 5, 25, 9),
      );

  int parseCalls = 0;

  static const _work = DayAgentCategory(
    id: 'cat_work',
    name: 'Work',
    colorHex: '5ED4B7',
  );

  @override
  Future<List<ParsedItem>> parseCaptureToItems(CaptureId id) async {
    parseCalls++;
    if (parseCalls == 1) return const [];
    return const [
      ParsedItem(
        id: 'parsed-invoices',
        kind: ParsedItemKind.newTask,
        title: 'Review outstanding invoices',
        category: _work,
        confidence: ParsedItemConfidence.high,
        estimateMinutes: 45,
      ),
    ];
  }
}
