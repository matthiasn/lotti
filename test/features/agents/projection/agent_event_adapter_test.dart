import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/agents/projection/agent_event_adapter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/entity_factories.dart';
import 'projection_test_fixtures.dart';

AgentLink _prevLink(String child, String parent, {DateTime? deletedAt}) =>
    AgentLink.messagePrev(
      id: 'lnk-$child-$parent',
      fromId: child,
      toId: parent,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      deletedAt: deletedAt,
    );

extension _AnyKind on glados.Any {
  glados.Generator<AgentMessageKind> get messageKind =>
      glados.AnyUtils(this).choose(AgentMessageKind.values);
}

void main() {
  group('agentEventKindFromMessageKind', () {
    glados.Glados(glados.any.messageKind).test('maps every message kind', (
      kind,
    ) {
      final expected = switch (kind) {
        AgentMessageKind.observation => AgentEventKind.observation,
        AgentMessageKind.summary => AgentEventKind.summary,
        _ => AgentEventKind.message,
      };

      expect(agentEventKindFromMessageKind(kind), expected, reason: '$kind');
    }, tags: 'glados');
  });

  group('agentEventsFromLog', () {
    AgentEvent eventFor(List<AgentEvent> events, String id) =>
        events.firstWhere((e) => e.id == id);

    test('reads causal parents from active messagePrev links, incl. joins', () {
      final events = agentEventsFromLog(
        [
          makeTestMessage(id: 'a'),
          makeTestMessage(id: 'b'),
          makeTestMessage(id: 'c'),
        ],
        [_prevLink('c', 'a'), _prevLink('c', 'b')],
      );

      // Join: two parents, normalized sorted-unique by AgentEvent.
      expect(eventFor(events, 'c').causalParents, ['a', 'b']);
      // Root: no incoming messagePrev edge.
      expect(eventFor(events, 'a').causalParents, isEmpty);
    });

    test('ignores deleted and non-messagePrev links', () {
      final events = agentEventsFromLog(
        [makeTestMessage(id: 'a'), makeTestMessage(id: 'b')],
        [
          _prevLink('b', 'a', deletedAt: DateTime(2024, 2)),
          AgentLink.agentTask(
            id: 'task-link',
            fromId: 'b',
            toId: 'a',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            vectorClock: null,
          ),
        ],
      );

      expect(eventFor(events, 'b').causalParents, isEmpty);
    });

    test('defaults hostId to empty, and applies hostIdOf when given', () {
      final message = makeTestMessage(id: 'a');

      expect(agentEventsFromLog([message], const []).single.hostId, '');
      expect(
        agentEventsFromLog(
          [message],
          const [],
          hostIdOf: (m) => 'host-${m.agentId}',
        ).single.hostId,
        'host-${message.agentId}',
      );
    });

    test('maps kind and defaults a null vector clock to an empty clock', () {
      final events = agentEventsFromLog(
        [
          makeTestMessage(id: 'o', kind: AgentMessageKind.observation),
          makeTestMessage(id: 'v', vectorClock: const VectorClock({'h0': 1})),
        ],
        const [],
      );

      expect(eventFor(events, 'o').kind, AgentEventKind.observation);
      expect(
        eventFor(events, 'o').vectorClock,
        const VectorClock(<String, int>{}),
      );
      expect(eventFor(events, 'v').vectorClock, const VectorClock({'h0': 1}));
    });
  });

  group('agentEventsFromLog — properties', () {
    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 120),
    ).test('causalParents reflect the materialized messagePrev edges', (dag) {
      // Materialize each generated event as a message + its messagePrev links,
      // then assert the adapter recovers the exact parent set.
      final messages = [
        for (final e in dag.events)
          makeTestMessage(id: e.id, vectorClock: e.vectorClock),
      ];
      final links = [
        for (final e in dag.events)
          for (final parent in e.causalParents) _prevLink(e.id, parent),
      ];

      final byId = {
        for (final event in agentEventsFromLog(messages, links))
          event.id: event,
      };
      for (final original in dag.events) {
        expect(
          byId[original.id]!.causalParents,
          original.causalParents,
          reason: '$dag',
        );
      }
    }, tags: 'glados');
  });
}
