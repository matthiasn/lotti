import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/projection/derived_agent_state.dart';

import '../test_data/constants.dart';
import '../test_data/entity_factories.dart';
import '../test_data/link_factories.dart';
import 'derived_agent_state_test_helpers.dart';

void main() {
  group('deriveAgentState — watermarks', () {
    test('folds each watermark as the max createdAt of its milestone', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [
          hMarker('w1', AgentMilestone.wakeCompleted, hDay(1)),
          hMarker('w2', AgentMilestone.wakeCompleted, hDay(5)),
          hMarker('w3', AgentMilestone.wakeCompleted, hDay(3)),
          hMarker('o1', AgentMilestone.oneOnOneCompleted, hDay(4)),
          hMarker('f1', AgentMilestone.feedbackScanCompleted, hDay(2)),
          hMarker('d1', AgentMilestone.dailyWakeCompleted, hDay(6)),
          hMarker('r1', AgentMilestone.weeklyReviewCompleted, hDay(7)),
        ],
        links: const [],
      );

      // Each watermark is independent and reflects only its own milestone.
      expect(derived.lastWakeAt, hDay(5));
      expect(derived.lastOneOnOneAt, hDay(4));
      expect(derived.lastFeedbackScanAt, hDay(2));
      expect(derived.lastDailyWakeAt, hDay(6));
      expect(derived.lastWeeklyReviewAt, hDay(7));
    });

    test('a watermark is null when no marker of that milestone exists', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [hMarker('w1', AgentMilestone.wakeCompleted, hDay(1))],
        links: const [],
      );

      expect(derived.lastWakeAt, hDay(1));
      expect(derived.lastOneOnOneAt, isNull);
      expect(derived.lastFeedbackScanAt, isNull);
      expect(derived.lastDailyWakeAt, isNull);
      expect(derived.lastWeeklyReviewAt, isNull);
    });

    test('a soft-deleted marker does not set the watermark', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [
          hMarker('w1', AgentMilestone.wakeCompleted, hDay(1)),
          hMarker(
            'w2',
            AgentMilestone.wakeCompleted,
            hDay(9),
            deletedAt: hDay(9),
          ),
        ],
        links: const [],
      );

      // The later marker is deleted, so the watermark stays at the live one.
      expect(derived.lastWakeAt, hDay(1));
    });

    test('plain (untagged) messages never set a watermark', () {
      final derived = deriveAgentState(
        agentId: kTestAgentId,
        messages: [
          makeTestMessage(id: 'u1', createdAt: hDay(9)),
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
          makeTestAgentEventLink(toId: 'event-9'),
          makeTestAgentDayLink(toId: 'day-9'),
          makeTestImproverTargetLink(toId: 'template-9'),
        ],
      );

      expect(derived.activeTaskId, 'task-9');
      expect(derived.activeProjectId, 'project-9');
      expect(derived.activeEventId, 'event-9');
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
            createdAt: hDay(1),
          ),
          makeTestAgentTaskLink(
            id: 'l-new',
            toId: 'task-new',
            createdAt: hDay(5),
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
            deletedAt: hDay(9),
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
            createdAt: hDay(1),
            deletedAt: hDay(9),
          ),
          makeTestAgentTaskLink(
            id: 'link-b',
            toId: 'task-b',
            createdAt: hDay(2),
            deletedAt: hDay(9),
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
          makeTestMessage(id: 'm1', createdAt: hDay(1)),
          makeTestMessage(id: 'm2', createdAt: hDay(2)),
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
}
