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

extension _AnyFoldScenario on glados.Any {
  glados.Generator<AgentMilestone> get milestone =>
      glados.AnyUtils(this).choose(AgentMilestone.values);

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
      glados.ExploreConfig(numRuns: 250),
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

      expect(report.error, isNotNull);
      expect(report.equivalent, isFalse);
    });
  });
}
