import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/projection/derived_agent_state.dart';
import 'package:lotti/features/agents/projection/shadow_projection.dart';

import '../test_data/constants.dart';
import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import 'derived_agent_state_test_helpers.dart';

void main() {
  group('reconcileAgentState', () {
    test('null watermarks on both sides stay null (the _laterOf(null, null) '
        'path)', () {
      final cache = makeTestState();

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: const [],
        links: const [],
      );

      expect(reconciled.lastWakeAt, isNull);
      expect(reconciled.slots.lastOneOnOneAt, isNull);
      expect(reconciled.slots.lastDailyWakeAt, isNull);
      expect(reconciled.slots.lastWeeklyReviewAt, isNull);
      // Nothing diverged → value-equal row, caller skips the persist.
      expect(reconciled, cache);
    });

    test('keeps a cached watermark the log does not yet have '
        '(migration-safe)', () {
      // A pre-marker agent: the cache holds lastWakeAt but the log has no
      // wakeCompleted marker. Reconcile must not null it out.
      final cache = makeTestState(lastWakeAt: hDay(5));

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: const [],
        links: const [],
      );

      expect(reconciled.lastWakeAt, hDay(5));
      // Nothing diverged → returns a value-equal row so the caller skips a
      // redundant persist.
      expect(reconciled, cache);
    });

    test('heals a watermark the cache lost to LWW (log has a newer '
        'marker)', () {
      final cache = makeTestState(lastWakeAt: hDay(1)); // clobbered/stale

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: [hMarker('w', AgentMilestone.wakeCompleted, hDay(9))],
        links: const [],
      );

      expect(reconciled.lastWakeAt, hDay(9));
      expect(reconciled, isNot(cache));
    });

    test('keeps the cache watermark when it is newer than the log (max)', () {
      final cache = makeTestState(lastWakeAt: hDay(9));

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: [hMarker('w', AgentMilestone.wakeCompleted, hDay(1))],
        links: const [],
      );

      expect(reconciled.lastWakeAt, hDay(9));
    });

    test('resolves active slots from links, falling back to the cache', () {
      final cache = makeTestState(
        slots: const AgentSlots(activeProjectId: 'cached-project'),
      );

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: const [],
        // A task link is present; no project link.
        links: [makeTestAgentTaskLink(toId: 'task-9')],
      );

      expect(reconciled.slots.activeTaskId, 'task-9'); // link-derived
      expect(reconciled.slots.activeProjectId, 'cached-project'); // fallback
    });

    test('leaves non-derived fields untouched while correcting derived '
        'ones', () {
      final cache = makeTestState(
        wakeCounter: 5,
        awaitingContent: true,
        scheduledWakeAt: hDay(3),
      ).copyWith(recentHeadMessageId: 'head-1');

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: [hMarker('w', AgentMilestone.wakeCompleted, hDay(9))],
        links: const [],
      );

      // Derived field corrected…
      expect(reconciled.lastWakeAt, hDay(9));
      // …everything the log does not own is preserved.
      expect(reconciled.wakeCounter.value, 5);
      expect(reconciled.awaitingContent, isTrue);
      expect(reconciled.scheduledWakeAt, hDay(3));
      expect(reconciled.recentHeadMessageId, 'head-1');
    });

    glados.Glados(
      glados.any.foldScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('never regresses a watermark and is idempotent', (scenario) {
      final cache = makeTestState(lastWakeAt: hDay(4));

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: scenario.markers,
        links: scenario.links,
      );

      // Exactly the later of (cache, log-derived) — never regresses either
      // side, never invents a third value. This is the convergence law: two
      // devices holding the same marker set (same `derivedWake`) and caches
      // bounded by it both land on `derivedWake`, so they agree.
      final derivedWake = deriveAgentState(
        agentId: kTestAgentId,
        messages: scenario.markers,
        links: scenario.links,
      ).lastWakeAt;
      final expectedWake =
          (derivedWake != null && derivedWake.isAfter(cache.lastWakeAt!))
          ? derivedWake
          : cache.lastWakeAt;
      expect(reconciled.lastWakeAt, expectedWake, reason: '$scenario');

      // Idempotent: reconciling the already-reconciled row changes nothing.
      final again = reconcileAgentState(
        cache: reconciled,
        messages: scenario.markers,
        links: scenario.links,
      );
      expect(again, reconciled, reason: '$scenario');
    }, tags: 'glados');

    glados.Glados2(
      glados.any.foldScenario,
      glados.any.cacheWatermarks,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'every watermark reconciles to max(derived, cache), order-independently',
      (scenario, cacheMarks) {
        final cache = makeTestState(
          lastWakeAt: cacheMarks.wakeAt,
          slots: AgentSlots(
            lastOneOnOneAt: cacheMarks.oneOnOneAt,
            lastFeedbackScanAt: cacheMarks.feedbackScanAt,
            lastDailyWakeAt: cacheMarks.dailyWakeAt,
            lastWeeklyReviewAt: cacheMarks.weeklyReviewAt,
          ),
        );
        final derived = deriveAgentState(
          agentId: kTestAgentId,
          messages: scenario.markers,
          links: scenario.links,
        );
        final why = '$scenario $cacheMarks';

        final reconciled = reconcileAgentState(
          cache: cache,
          messages: scenario.markers,
          links: scenario.links,
        );

        // The algebraic merge law, asserted on *every* watermark field against
        // an independently-computed max — `lastWakeAt` lives on the row, the
        // four ritual watermarks on `slots`.
        expect(
          reconciled.lastWakeAt,
          hLaterOfOracle(derived.lastWakeAt, cache.lastWakeAt),
          reason: why,
        );
        expect(
          reconciled.slots.lastOneOnOneAt,
          hLaterOfOracle(derived.lastOneOnOneAt, cache.slots.lastOneOnOneAt),
          reason: why,
        );
        expect(
          reconciled.slots.lastFeedbackScanAt,
          hLaterOfOracle(
            derived.lastFeedbackScanAt,
            cache.slots.lastFeedbackScanAt,
          ),
          reason: why,
        );
        expect(
          reconciled.slots.lastDailyWakeAt,
          hLaterOfOracle(derived.lastDailyWakeAt, cache.slots.lastDailyWakeAt),
          reason: why,
        );
        expect(
          reconciled.slots.lastWeeklyReviewAt,
          hLaterOfOracle(
            derived.lastWeeklyReviewAt,
            cache.slots.lastWeeklyReviewAt,
          ),
          reason: why,
        );

        // max is commutative & idempotent: a device whose cache already holds
        // the reconciled watermarks reconciles to the same values (no value is
        // ever invented beyond the two inputs' max).
        final reReconciled = reconcileAgentState(
          cache: reconciled,
          messages: scenario.markers,
          links: scenario.links,
        );
        expect(reReconciled.lastWakeAt, reconciled.lastWakeAt, reason: why);
        expect(
          reReconciled.slots.lastOneOnOneAt,
          reconciled.slots.lastOneOnOneAt,
          reason: why,
        );
        expect(
          reReconciled.slots.lastWeeklyReviewAt,
          reconciled.slots.lastWeeklyReviewAt,
          reason: why,
        );
      },
      tags: 'glados',
    );
  });

  group('reconcile convergence (partition + heal)', () {
    test('two devices converge a watermark to the later ritual — no missed '
        'or double review', () {
      // Each device ran the ritual on its own side of a partition: device A at
      // day 3, device B at day 7. Under LWW the synced cache could keep either
      // device's value — model each cache holding only its own ritual time.
      final cacheA = makeTestState(slots: AgentSlots(lastOneOnOneAt: hDay(3)));
      final cacheB = makeTestState(slots: AgentSlots(lastOneOnOneAt: hDay(7)));
      // After heal both devices hold both ritual markers (log set-union).
      final healedLog = [
        hMarker('mA', AgentMilestone.oneOnOneCompleted, hDay(3)),
        hMarker('mB', AgentMilestone.oneOnOneCompleted, hDay(7)),
      ];

      final reconciledA = reconcileAgentState(
        cache: cacheA,
        messages: healedLog,
        links: const [],
      );
      final reconciledB = reconcileAgentState(
        cache: cacheB,
        messages: healedLog,
        links: const [],
      );

      // Both self-heal to the later ritual and agree — the partition can no
      // longer hide a ritual (a "missed review") or keep a stale one.
      expect(reconciledA.slots.lastOneOnOneAt, hDay(7));
      expect(reconciledB.slots.lastOneOnOneAt, hDay(7));
      expect(
        reconciledA.slots.lastOneOnOneAt,
        reconciledB.slots.lastOneOnOneAt,
      );
    });

    test('two devices converge an active slot to the most-recent link', () {
      // A pointed the agent at task-X (day 1); B re-pointed it at task-Y
      // (day 5). After heal both hold both links.
      final healedLinks = [
        makeTestAgentTaskLink(id: 'lA', toId: 'task-X', createdAt: hDay(1)),
        makeTestAgentTaskLink(id: 'lB', toId: 'task-Y', createdAt: hDay(5)),
      ];
      final cacheA = makeTestState(
        slots: const AgentSlots(activeTaskId: 'task-X'),
      );
      final cacheB = makeTestState(
        slots: const AgentSlots(activeTaskId: 'task-Y'),
      );

      final reconciledA = reconcileAgentState(
        cache: cacheA,
        messages: const [],
        links: healedLinks,
      );
      final reconciledB = reconcileAgentState(
        cache: cacheB,
        messages: const [],
        links: healedLinks,
      );

      expect(reconciledA.slots.activeTaskId, 'task-Y');
      expect(reconciledB.slots.activeTaskId, 'task-Y');
    });
  });

  group('compareDerivedAgentState — full divergence & report semantics', () {
    test('reports every diverging field', () {
      final messages = [
        hMarker('w', AgentMilestone.wakeCompleted, hDay(1)),
        hMarker('o', AgentMilestone.oneOnOneCompleted, hDay(2)),
        hMarker('f', AgentMilestone.feedbackScanCompleted, hDay(3)),
        hMarker('d', AgentMilestone.dailyWakeCompleted, hDay(4)),
        hMarker('r', AgentMilestone.weeklyReviewCompleted, hDay(5)),
      ];
      final links = [
        makeTestAgentTaskLink(toId: 'task-log'),
        makeTestAgentProjectLink(toId: 'project-log'),
        makeTestAgentEventLink(toId: 'event-log'),
        makeTestAgentDayLink(toId: 'day-log'),
        makeTestImproverTargetLink(toId: 'template-log'),
      ];
      // The cache diverges on every log-backed field.
      final live = makeTestState(
        lastWakeAt: hDay(11),
        slots: AgentSlots(
          activeTaskId: 'task-cache',
          activeProjectId: 'project-cache',
          activeEventId: 'event-cache',
          activeDayId: 'day-cache',
          activeTemplateId: 'template-cache',
          lastOneOnOneAt: hDay(12),
          lastFeedbackScanAt: hDay(13),
          lastDailyWakeAt: hDay(14),
          lastWeeklyReviewAt: hDay(15),
        ),
      );

      final report = compareDerivedAgentState(
        messages: messages,
        links: links,
        liveState: live,
      );

      expect(report.equivalent, isFalse);
      expect(report.fieldMismatches.map((m) => m.field).toSet(), {
        'activeTaskId',
        'activeProjectId',
        'activeEventId',
        'activeDayId',
        'activeTemplateId',
        'lastWakeAt',
        'lastOneOnOneAt',
        'lastFeedbackScanAt',
        'lastDailyWakeAt',
        'lastWeeklyReviewAt',
      });
      final task = report.fieldMismatches.firstWhere(
        (m) => m.field == 'activeTaskId',
      );
      expect(task.derived, 'task-log');
      expect(task.live, 'task-cache');
      // The event slot's mismatch carries the log-derived target and the cache
      // value — exercising the activeEventId branch of compareDerivedAgentState.
      final event = report.fieldMismatches.firstWhere(
        (m) => m.field == 'activeEventId',
      );
      expect(event.derived, 'event-log');
      expect(event.live, 'event-cache');
    });

    test('equivalent on a fresh empty agent (empty head status)', () {
      final report = compareDerivedAgentState(
        messages: const [],
        links: const [],
        liveState: makeTestState(),
      );

      expect(report.shadow.status, ShadowProjectionStatus.empty);
      expect(report.equivalent, isTrue);
    });

    test('equivalent under an expected fork when no field diverges', () {
      // Two parentless messages → two heads (a fork); the live head is one of
      // them. No markers/links, so the derived fields match the empty cache.
      final report = compareDerivedAgentState(
        messages: [
          makeTestMessage(id: 'm1'),
          makeTestMessage(id: 'm2'),
        ],
        links: const [],
        liveState: makeTestState().copyWith(recentHeadMessageId: 'm1'),
      );

      expect(report.shadow.status, ShadowProjectionStatus.forked);
      expect(report.equivalent, isTrue);
    });

    test('DerivedFieldMismatch carries its values and has value equality', () {
      // Runtime (non-const) instances, so Equatable actually compares `props`
      // rather than short-circuiting on const-canonicalized identity.
      final a = DerivedFieldMismatch(
        field: 'lastWakeAt',
        derived: hDay(1),
        live: hDay(2),
      );
      final b = DerivedFieldMismatch(
        field: 'lastWakeAt',
        derived: hDay(1),
        live: hDay(2),
      );

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.toString(), contains('lastWakeAt'));
    });

    test('DerivedStateReport has value equality', () {
      const shadow = ShadowProjectionReport(
        status: ShadowProjectionStatus.empty,
        projectedHeadIds: [],
        liveHeadId: null,
        danglingParentIds: [],
      );
      // A runtime mismatch keeps the reports non-const (distinct instances).
      final mismatch = DerivedFieldMismatch(
        field: 'f',
        derived: hDay(1),
        live: hDay(2),
      );
      final r1 = DerivedStateReport(
        shadow: shadow,
        fieldMismatches: [mismatch],
      );
      final r2 = DerivedStateReport(
        shadow: shadow,
        fieldMismatches: [mismatch],
      );

      expect(identical(r1, r2), isFalse);
      expect(r1, r2);
    });
  });
}
