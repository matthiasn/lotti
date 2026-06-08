
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_link.dart';
import 'agent_link_test_helpers.dart';

void main() {
  final createdAt = DateTime(2026, 2, 20);
  final updatedAt = DateTime(2026, 2, 20, 12);

  group('AgentLinkSelection', () {
    test('orderedPrimaryFirst sorts by createdAt then id descending', () {
      final links = [
        AgentLink.agentTask(
          id: 'link-b',
          fromId: 'agent-b',
          toId: 'task-1',
          createdAt: DateTime(2026, 2, 20, 9),
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.agentTask(
          id: 'link-c',
          fromId: 'agent-c',
          toId: 'task-1',
          createdAt: DateTime(2026, 2, 20, 10),
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.agentTask(
          id: 'link-a',
          fromId: 'agent-a',
          toId: 'task-1',
          createdAt: DateTime(2026, 2, 20, 10),
          updatedAt: updatedAt,
          vectorClock: null,
        ),
      ];

      final ordered = links.orderedPrimaryFirst();

      expect(ordered.map((link) => link.id), ['link-c', 'link-a', 'link-b']);
    });

    test(
      'selectPrimary returns the first ordered link and throws on empty',
      () {
        final links = [
          AgentLink.agentProject(
            id: 'link-1',
            fromId: 'agent-1',
            toId: 'project-1',
            createdAt: DateTime(2026, 2, 20, 10),
            updatedAt: updatedAt,
            vectorClock: null,
          ),
          AgentLink.agentProject(
            id: 'link-2',
            fromId: 'agent-2',
            toId: 'project-1',
            createdAt: DateTime(2026, 2, 20, 11),
            updatedAt: updatedAt,
            vectorClock: null,
          ),
        ];

        expect(links.selectPrimary().id, 'link-2');
        expect(
          () => <AgentLink>[].selectPrimary(),
          throwsA(isA<StateError>()),
        );
      },
    );

    glados.Glados(
      glados.any.agentLinkSelectionScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated primary ordering semantics', (scenario) {
      final links = scenario.agentLinks;
      final ordered = links.orderedPrimaryFirst();

      expect(
        ordered.map((link) => link.id).toList(),
        scenario.expectedOrderedIds,
        reason: '$scenario',
      );

      if (links.isEmpty) {
        expect(links.selectPrimary, throwsA(isA<StateError>()));
      } else {
        expect(
          links.selectPrimary().id,
          scenario.expectedOrderedIds.first,
          reason: '$scenario',
        );
      }
    }, tags: 'glados');
  });

  group('AgentLinkSoftDelete extension', () {
    final deletedAt = DateTime(2026, 4, 6, 15);

    test('softDeleted sets deletedAt and updatedAt on every variant', () {
      final variants = <AgentLink>[
        AgentLink.basic(
          id: 'l1',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.agentState(
          id: 'l2',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.messagePrev(
          id: 'l3',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.messagePayload(
          id: 'l4',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.toolEffect(
          id: 'l5',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.agentTask(
          id: 'l6',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.captureToParsedItem(
          id: 'l-capture',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.parsedItemToTask(
          id: 'l-parsed-task',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.captureToPlan(
          id: 'l-capture-plan',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.attentionRequestEvidence(
          id: 'l-attention-evidence',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.attentionAwardRequest(
          id: 'l-attention-award-request',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.attentionAwardPlan(
          id: 'l-attention-award-plan',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.templateAssignment(
          id: 'l7',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.improverTarget(
          id: 'l8',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.agentProject(
          id: 'l9',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.agentDay(
          id: 'l-day',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
        AgentLink.soulAssignment(
          id: 'l10',
          fromId: 'a',
          toId: 'b',
          createdAt: createdAt,
          updatedAt: updatedAt,
          vectorClock: null,
        ),
      ];

      for (final link in variants) {
        final deleted = link.softDeleted(deletedAt);
        expect(deleted.deletedAt, deletedAt, reason: '${link.runtimeType}');
        expect(deleted.updatedAt, deletedAt, reason: '${link.runtimeType}');
        // Other fields unchanged.
        expect(deleted.id, link.id, reason: '${link.runtimeType}');
        expect(deleted.fromId, link.fromId, reason: '${link.runtimeType}');
        expect(deleted.toId, link.toId, reason: '${link.runtimeType}');
        expect(
          deleted.createdAt,
          link.createdAt,
          reason: '${link.runtimeType}',
        );
      }
    });
  });
}
