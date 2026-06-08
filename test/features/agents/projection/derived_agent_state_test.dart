import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/derived_agent_state.dart';
import 'package:lotti/features/agents/projection/shadow_projection.dart';

import '../test_data/constants.dart';
import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';

/// A milestone marker message — what `AgentSyncService.appendMilestone` emits.
AgentMessageEntity _marker(
  String id,
  AgentMilestone milestone,
  DateTime createdAt, {
  DateTime? deletedAt,
}) {
  final message = makeTestMessage(
    id: id,
    kind: AgentMessageKind.system,
    createdAt: createdAt,
    metadata: AgentMessageMetadata(milestone: milestone),
  );
  return deletedAt == null ? message : message.copyWith(deletedAt: deletedAt);
}

DateTime _day(int n) => DateTime(2024, 3, n);

/// One generated fold input: milestone markers and slot links with arbitrary
/// timestamps (ties included) for one agent, used to prove the fold is a pure
/// function of the *set* — i.e. it converges across arrival orders.
class _GeneratedFoldScenario {
  const _GeneratedFoldScenario({required this.markers, required this.links});

  final List<AgentMessageEntity> markers;
  final List<AgentLink> links;

  @override
  String toString() =>
      '_GeneratedFoldScenario(markers: ${markers.length}, '
      'links: ${links.length})';
}

/// Arbitrary cache watermark values for all five watermark fields. Each int is
/// a day in `0..7`, where `0` encodes a null watermark and `1..7` encode
/// `_day(n)` — the `1..7` range overlaps the generated marker days so cache and
/// log-derived watermarks tie, are above, and are below each other across runs.
class _CacheWatermarks {
  const _CacheWatermarks({
    required this.wake,
    required this.oneOnOne,
    required this.feedbackScan,
    required this.dailyWake,
    required this.weeklyReview,
  });

  final int wake;
  final int oneOnOne;
  final int feedbackScan;
  final int dailyWake;
  final int weeklyReview;

  static DateTime? _at(int day) => day == 0 ? null : _day(day);

  DateTime? get wakeAt => _at(wake);
  DateTime? get oneOnOneAt => _at(oneOnOne);
  DateTime? get feedbackScanAt => _at(feedbackScan);
  DateTime? get dailyWakeAt => _at(dailyWake);
  DateTime? get weeklyReviewAt => _at(weeklyReview);

  @override
  String toString() =>
      '_CacheWatermarks(wake: $wake, oneOnOne: $oneOnOne, '
      'feedbackScan: $feedbackScan, dailyWake: $dailyWake, '
      'weeklyReview: $weeklyReview)';
}

/// The later of two nullable timestamps — the reconcile law (`max`, null = "no
/// value"), recomputed in the test independent of the private `_laterOf`.
DateTime? _laterOfOracle(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

extension _AnyFoldScenario on glados.Any {
  glados.Generator<AgentMilestone> get milestone =>
      glados.AnyUtils(this).choose(AgentMilestone.values);

  glados.Generator<_CacheWatermarks> get cacheWatermarks {
    glados.Generator<int> day() => glados.IntAnys(this).intInRange(0, 8);
    return glados.CombinableAny(this).combine5(
      day(),
      day(),
      day(),
      day(),
      day(),
      (int w, int o, int f, int d, int r) => _CacheWatermarks(
        wake: w,
        oneOnOne: o,
        feedbackScan: f,
        dailyWake: d,
        weeklyReview: r,
      ),
    );
  }

  glados.Generator<_GeneratedFoldScenario> get foldScenario =>
      glados.CombinableAny(this).combine2(
        // Marker specs: (milestone, day-of-month tie-prone in 1..6).
        glados.ListAnys(this).listWithLengthInRange(
          0,
          8,
          glados.CombinableAny(this).combine2(
            milestone,
            glados.IntAnys(this).intInRange(1, 7),
            (AgentMilestone m, int day) => (m, day),
          ),
        ),
        // Link specs: (slot 0..3, target 0..2, day 1..6, fromOtherAgent).
        glados.ListAnys(this).listWithLengthInRange(
          0,
          8,
          glados.CombinableAny(this).combine4(
            glados.IntAnys(this).intInRange(0, 4),
            glados.IntAnys(this).intInRange(0, 3),
            glados.IntAnys(this).intInRange(1, 7),
            glados.AnyUtils(this).choose(const [false, true]),
            (int slot, int target, int day, bool fromOther) =>
                (slot, target, day, fromOther),
          ),
        ),
        (
          List<(AgentMilestone, int)> markerSpecs,
          List<(int, int, int, bool)> linkSpecs,
        ) {
          final markers = [
            for (final (i, spec) in markerSpecs.indexed)
              _marker('m$i', spec.$1, _day(spec.$2)),
          ];
          final links = [
            for (final (i, spec) in linkSpecs.indexed)
              _slotLink(
                index: i,
                slot: spec.$1,
                target: 'target-${spec.$2}',
                createdAt: _day(spec.$3),
                fromId: spec.$4 ? 'other-agent-$i' : kTestAgentId,
              ),
          ];
          return _GeneratedFoldScenario(markers: markers, links: links);
        },
      );
}

AgentLink _slotLink({
  required int index,
  required int slot,
  required String target,
  required DateTime createdAt,
  required String fromId,
}) {
  final id = 'link-$index';
  return switch (slot % 4) {
    0 => makeTestAgentTaskLink(
      id: id,
      fromId: fromId,
      toId: target,
      createdAt: createdAt,
    ),
    1 => makeTestAgentProjectLink(
      id: id,
      fromId: fromId,
      toId: target,
      createdAt: createdAt,
    ),
    2 => makeTestAgentDayLink(
      id: id,
      fromId: fromId,
      toId: target,
      createdAt: createdAt,
    ),
    _ => makeTestImproverTargetLink(
      id: id,
      fromId: fromId,
      toId: target,
      createdAt: createdAt,
    ),
  };
}

void main() {
  group('deriveAgentState — watermarks', () {
    test('folds each watermark as the max createdAt of its milestone', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [
          _marker('w1', AgentMilestone.wakeCompleted, _day(1)),
          _marker('w2', AgentMilestone.wakeCompleted, _day(5)),
          _marker('w3', AgentMilestone.wakeCompleted, _day(3)),
          _marker('o1', AgentMilestone.oneOnOneCompleted, _day(4)),
          _marker('f1', AgentMilestone.feedbackScanCompleted, _day(2)),
          _marker('d1', AgentMilestone.dailyWakeCompleted, _day(6)),
          _marker('r1', AgentMilestone.weeklyReviewCompleted, _day(7)),
        ],
        links: const [],
      );

      // Each watermark is independent and reflects only its own milestone.
      expect(derived.lastWakeAt, _day(5));
      expect(derived.lastOneOnOneAt, _day(4));
      expect(derived.lastFeedbackScanAt, _day(2));
      expect(derived.lastDailyWakeAt, _day(6));
      expect(derived.lastWeeklyReviewAt, _day(7));
    });

    test('a watermark is null when no marker of that milestone exists', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [_marker('w1', AgentMilestone.wakeCompleted, _day(1))],
        links: const [],
      );

      expect(derived.lastWakeAt, _day(1));
      expect(derived.lastOneOnOneAt, isNull);
      expect(derived.lastFeedbackScanAt, isNull);
      expect(derived.lastDailyWakeAt, isNull);
      expect(derived.lastWeeklyReviewAt, isNull);
    });

    test('a soft-deleted marker does not set the watermark', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [
          _marker('w1', AgentMilestone.wakeCompleted, _day(1)),
          _marker(
            'w2',
            AgentMilestone.wakeCompleted,
            _day(9),
            deletedAt: _day(9),
          ),
        ],
        links: const [],
      );

      // The later marker is deleted, so the watermark stays at the live one.
      expect(derived.lastWakeAt, _day(1));
    });

    test('plain (untagged) messages never set a watermark', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [
          makeTestMessage(id: 'u1', createdAt: _day(9)),
          makeTestMessage(id: 'u2', kind: AgentMessageKind.observation),
        ],
        links: const [],
      );

      expect(derived.lastWakeAt, isNull);
    });
  });

  group('deriveAgentState — active slots', () {
    test('resolves each slot from its agent→target link', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: const [],
        links: [
          makeTestAgentTaskLink(toId: 'task-9'),
          makeTestAgentProjectLink(toId: 'project-9'),
          makeTestAgentDayLink(toId: 'day-9'),
          makeTestImproverTargetLink(toId: 'template-9'),
        ],
      );

      expect(derived.activeTaskId, 'task-9');
      expect(derived.activeProjectId, 'project-9');
      expect(derived.activeDayId, 'day-9');
      expect(derived.activeTemplateId, 'template-9');
    });

    test('the most recent link wins when an agent is re-linked', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: const [],
        links: [
          makeTestAgentTaskLink(
            id: 'l-old',
            toId: 'task-old',
            createdAt: _day(1),
          ),
          makeTestAgentTaskLink(
            id: 'l-new',
            toId: 'task-new',
            createdAt: _day(5),
          ),
        ],
      );

      expect(derived.activeTaskId, 'task-new');
    });

    test('ignores links from a different agent', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: const [],
        links: [
          makeTestAgentTaskLink(fromId: 'someone-else', toId: 'task-other'),
        ],
      );

      expect(derived.activeTaskId, isNull);
    });

    test('ignores soft-deleted links', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: const [],
        links: [
          makeTestAgentTaskLink(
            toId: 'task-deleted',
            deletedAt: _day(9),
          ),
        ],
      );

      expect(derived.activeTaskId, isNull);
    });

    test('slot is null when every matching link is soft-deleted', () {
      // _primaryActiveLinkTarget must return null (not throw on .first)
      // when the active-link filter leaves nothing to order.
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: const [],
        links: [
          makeTestAgentTaskLink(
            id: 'link-a',
            toId: 'task-a',
            createdAt: _day(1),
            deletedAt: _day(9),
          ),
          makeTestAgentTaskLink(
            id: 'link-b',
            toId: 'task-b',
            createdAt: _day(2),
            deletedAt: _day(9),
          ),
        ],
      );

      expect(derived.activeTaskId, isNull);
    });

    test('a slot is null when the agent has no link of that type', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: const [],
        links: [makeTestAgentTaskLink(toId: 'task-9')],
      );

      expect(derived.activeTaskId, 'task-9');
      expect(derived.activeProjectId, isNull);
      expect(derived.activeDayId, isNull);
      expect(derived.activeTemplateId, isNull);
    });
  });

  group('deriveAgentState — structural projection', () {
    test('heads reflect the messagePrev DAG tip', () {
      // m2 → m1 (m2 is the tip / head).
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [
          makeTestMessage(id: 'm1', createdAt: _day(1)),
          makeTestMessage(id: 'm2', createdAt: _day(2)),
        ],
        links: [makeTestMessagePrevLink(fromId: 'm2', toId: 'm1')],
      );

      expect(derived.projection.headIds, ['m2']);
    });
  });

  group('deriveAgentState — convergence (order independence)', () {
    glados.Glados(
      glados.any.foldScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('two devices holding the same log set derive equal state', (
      scenario,
    ) {
      // Device A sees the log in generated order; device B sees it reversed —
      // the strongest cheap permutation. A pure fold of the *set* must agree.
      final deviceA = deriveAgentState(
        agentId: kTestAgentId,
        messages: scenario.markers,
        links: scenario.links,
      );
      final deviceB = deriveAgentState(
        agentId: kTestAgentId,
        messages: scenario.markers.reversed.toList(),
        links: scenario.links.reversed.toList(),
      );

      expect(deviceA, deviceB, reason: '$scenario');
    }, tags: 'glados');
  });

  group('compareDerivedAgentState', () {
    test('equivalent when the cache reproduces the log-derived state', () {
      final messages = [
        makeTestMessage(id: 'm1', createdAt: _day(1)),
        _marker('w1', AgentMilestone.wakeCompleted, _day(2)),
      ];
      final links = [
        makeTestMessagePrevLink(fromId: 'w1', toId: 'm1'),
        makeTestAgentTaskLink(toId: 'task-9'),
      ];
      final live = makeTestState(
        slots: const AgentSlots(activeTaskId: 'task-9'),
        lastWakeAt: _day(2),
      ).copyWith(recentHeadMessageId: 'w1');

      final report = compareDerivedAgentState(
        messages: messages,
        links: links,
        liveState: live,
      );

      expect(report.equivalent, isTrue);
      expect(report.fieldMismatches, isEmpty);
      expect(report.shadow.status, ShadowProjectionStatus.match);
    });

    test('reports the diverging field when the cache is stale', () {
      final messages = [_marker('w1', AgentMilestone.wakeCompleted, _day(5))];
      final live = makeTestState(
        lastWakeAt: _day(1), // stale — log says day 5
      ).copyWith(recentHeadMessageId: 'w1');

      final report = compareDerivedAgentState(
        messages: messages,
        links: const [],
        liveState: live,
      );

      expect(report.equivalent, isFalse);
      expect(
        report.fieldMismatches.map((m) => m.field),
        contains('lastWakeAt'),
      );
      final mismatch = report.fieldMismatches.singleWhere(
        (m) => m.field == 'lastWakeAt',
      );
      expect(mismatch.derived, _day(5));
      expect(mismatch.live, _day(1));
    });

    test('captures a structural fold failure as error', () {
      // A messagePrev cycle (m1 → m2 → m1) makes canonicalOrder throw; the
      // compare must capture it as an error rather than crash.
      final messages = [
        makeTestMessage(id: 'm1', createdAt: _day(1)),
        makeTestMessage(id: 'm2', createdAt: _day(2)),
      ];
      final links = [
        makeTestMessagePrevLink(id: 'e1', fromId: 'm1', toId: 'm2'),
        makeTestMessagePrevLink(id: 'e2', fromId: 'm2', toId: 'm1'),
      ];
      final live = makeTestState();

      final report = compareDerivedAgentState(
        messages: messages,
        links: links,
        liveState: live,
      );

      // The messagePrev cycle surfaces as the kernel's structural exception,
      // captured (not thrown) so the compare never crashes a production path.
      expect(report.error, contains('ProjectionCycleException'));
      expect(report.equivalent, isFalse);
    });
  });

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
      final cache = makeTestState(lastWakeAt: _day(5));

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: const [],
        links: const [],
      );

      expect(reconciled.lastWakeAt, _day(5));
      // Nothing diverged → returns a value-equal row so the caller skips a
      // redundant persist.
      expect(reconciled, cache);
    });

    test('heals a watermark the cache lost to LWW (log has a newer '
        'marker)', () {
      final cache = makeTestState(lastWakeAt: _day(1)); // clobbered/stale

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: [_marker('w', AgentMilestone.wakeCompleted, _day(9))],
        links: const [],
      );

      expect(reconciled.lastWakeAt, _day(9));
      expect(reconciled, isNot(cache));
    });

    test('keeps the cache watermark when it is newer than the log (max)', () {
      final cache = makeTestState(lastWakeAt: _day(9));

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: [_marker('w', AgentMilestone.wakeCompleted, _day(1))],
        links: const [],
      );

      expect(reconciled.lastWakeAt, _day(9));
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
        scheduledWakeAt: _day(3),
      ).copyWith(recentHeadMessageId: 'head-1');

      final reconciled = reconcileAgentState(
        cache: cache,
        messages: [_marker('w', AgentMilestone.wakeCompleted, _day(9))],
        links: const [],
      );

      // Derived field corrected…
      expect(reconciled.lastWakeAt, _day(9));
      // …everything the log does not own is preserved.
      expect(reconciled.wakeCounter.value, 5);
      expect(reconciled.awaitingContent, isTrue);
      expect(reconciled.scheduledWakeAt, _day(3));
      expect(reconciled.recentHeadMessageId, 'head-1');
    });

    glados.Glados(
      glados.any.foldScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('never regresses a watermark and is idempotent', (scenario) {
      final cache = makeTestState(lastWakeAt: _day(4));

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
          _laterOfOracle(derived.lastWakeAt, cache.lastWakeAt),
          reason: why,
        );
        expect(
          reconciled.slots.lastOneOnOneAt,
          _laterOfOracle(derived.lastOneOnOneAt, cache.slots.lastOneOnOneAt),
          reason: why,
        );
        expect(
          reconciled.slots.lastFeedbackScanAt,
          _laterOfOracle(
            derived.lastFeedbackScanAt,
            cache.slots.lastFeedbackScanAt,
          ),
          reason: why,
        );
        expect(
          reconciled.slots.lastDailyWakeAt,
          _laterOfOracle(derived.lastDailyWakeAt, cache.slots.lastDailyWakeAt),
          reason: why,
        );
        expect(
          reconciled.slots.lastWeeklyReviewAt,
          _laterOfOracle(
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
      final cacheA = makeTestState(slots: AgentSlots(lastOneOnOneAt: _day(3)));
      final cacheB = makeTestState(slots: AgentSlots(lastOneOnOneAt: _day(7)));
      // After heal both devices hold both ritual markers (log set-union).
      final healedLog = [
        _marker('mA', AgentMilestone.oneOnOneCompleted, _day(3)),
        _marker('mB', AgentMilestone.oneOnOneCompleted, _day(7)),
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
      expect(reconciledA.slots.lastOneOnOneAt, _day(7));
      expect(reconciledB.slots.lastOneOnOneAt, _day(7));
      expect(
        reconciledA.slots.lastOneOnOneAt,
        reconciledB.slots.lastOneOnOneAt,
      );
    });

    test('two devices converge an active slot to the most-recent link', () {
      // A pointed the agent at task-X (day 1); B re-pointed it at task-Y
      // (day 5). After heal both hold both links.
      final healedLinks = [
        makeTestAgentTaskLink(id: 'lA', toId: 'task-X', createdAt: _day(1)),
        makeTestAgentTaskLink(id: 'lB', toId: 'task-Y', createdAt: _day(5)),
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
        _marker('w', AgentMilestone.wakeCompleted, _day(1)),
        _marker('o', AgentMilestone.oneOnOneCompleted, _day(2)),
        _marker('f', AgentMilestone.feedbackScanCompleted, _day(3)),
        _marker('d', AgentMilestone.dailyWakeCompleted, _day(4)),
        _marker('r', AgentMilestone.weeklyReviewCompleted, _day(5)),
      ];
      final links = [
        makeTestAgentTaskLink(toId: 'task-log'),
        makeTestAgentProjectLink(toId: 'project-log'),
        makeTestAgentDayLink(toId: 'day-log'),
        makeTestImproverTargetLink(toId: 'template-log'),
      ];
      // The cache diverges on every log-backed field.
      final live = makeTestState(
        lastWakeAt: _day(11),
        slots: AgentSlots(
          activeTaskId: 'task-cache',
          activeProjectId: 'project-cache',
          activeDayId: 'day-cache',
          activeTemplateId: 'template-cache',
          lastOneOnOneAt: _day(12),
          lastFeedbackScanAt: _day(13),
          lastDailyWakeAt: _day(14),
          lastWeeklyReviewAt: _day(15),
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
        derived: _day(1),
        live: _day(2),
      );
      final b = DerivedFieldMismatch(
        field: 'lastWakeAt',
        derived: _day(1),
        live: _day(2),
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
        derived: _day(1),
        live: _day(2),
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
