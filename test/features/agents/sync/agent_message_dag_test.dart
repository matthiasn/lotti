import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_message_dag.dart';

import '../test_data/entity_factories.dart';
import 'in_memory_agent_repository.dart';

void main() {
  late InMemoryAgentRepository repo;
  late AgentMessageDag dag;

  Future<void> edge(String child, String parent, {DateTime? deletedAt}) =>
      repo.upsertLink(
        AgentLink.messagePrev(
          id: 'msgprev-$child-$parent',
          fromId: child,
          toId: parent,
          createdAt: DateTime(2026, 9),
          updatedAt: DateTime(2026, 9),
          vectorClock: null,
          deletedAt: deletedAt,
        ),
      );

  void messages(List<String> ids) => repo.seed([
    for (final id in ids)
      makeTestMessage(id: id, agentId: 'agent-1', createdAt: DateTime(2026, 9)),
  ]);

  setUp(() async {
    repo = InMemoryAgentRepository();
    dag = AgentMessageDag(repo);
    // r ← a1 ← a2 and r ← b1; `c1` names `a2`, but its row has not arrived.
    messages(['r', 'a1', 'a2', 'b1']);
    await edge('a1', 'r');
    await edge('a2', 'a1');
    await edge('b1', 'r');
    await edge('c1', 'a2');
  });

  group('isAncestor', () {
    test('follows present children forward, over any distance', () async {
      expect(await dag.isAncestor('r', 'a2'), isTrue);
      expect(await dag.isAncestor('a1', 'a2'), isTrue);
    });

    test('is false for a descendant, a sibling branch, or itself', () async {
      expect(await dag.isAncestor('a2', 'r'), isFalse);
      expect(await dag.isAncestor('a1', 'b1'), isFalse);
      expect(await dag.isAncestor('a1', 'a1'), isFalse);
    });

    test('does not count a child whose row has not arrived', () async {
      expect(await dag.isAncestor('a2', 'c1'), isFalse);
    });

    test('does not count a deleted edge or a deleted row', () async {
      messages(['d1']);
      await edge('d1', 'b1', deletedAt: DateTime(2026, 9, 2));
      expect(await dag.isAncestor('b1', 'd1'), isFalse);

      repo.seed([
        makeTestMessage(
          id: 'a1',
          agentId: 'agent-1',
          createdAt: DateTime(2026, 9),
        ).copyWith(deletedAt: DateTime(2026, 9, 2)),
      ]);
      expect(await dag.isAncestor('r', 'a2'), isFalse);
    });

    test('terminates on a cycle synced in from a peer', () async {
      await edge('r', 'a2');
      expect(await dag.isAncestor('a1', 'b1'), isTrue);
      expect(await dag.isAncestor('a1', 'x'), isFalse);
    });
  });

  group('ancestryOf', () {
    test('answers for the pair, in the direction the DAG shows', () async {
      final ancestry = await dag.ancestryOf('a2', 'r');

      expect(ancestry('r', 'a2'), isTrue);
      expect(ancestry('a2', 'r'), isFalse);
      // Only the pair it was read for.
      expect(ancestry('r', 'a1'), isFalse);

      final reversed = await dag.ancestryOf('r', 'a2');
      expect(reversed('r', 'a2'), isTrue);
      expect(reversed('a2', 'r'), isFalse);
    });

    test('knows no order for a fork, an unset head or one head', () async {
      final fork = await dag.ancestryOf('a2', 'b1');
      expect(fork('a2', 'b1'), isFalse);
      expect(fork('b1', 'a2'), isFalse);

      for (final (a, b) in [(null, 'a1'), ('a1', null), ('a1', 'a1')]) {
        final none = await dag.ancestryOf(a, b);
        expect(none('a1', 'a2'), isFalse);
        expect(none('r', 'a1'), isFalse);
      }
    });
  });

  group('tipFrom', () {
    test('keeps a head nothing here descends from', () async {
      expect(await dag.tipFrom('b1'), 'b1');
      // `c1` names `a2`, but its row has not arrived.
      expect(await dag.tipFrom('a2'), 'a2');
      expect(await dag.tipFrom('unknown'), 'unknown');
    });

    test('walks past a trailing head to a tip, the lowest id first', () async {
      expect(await dag.tipFrom('a1'), 'a2');
      // `r` has two children: `a1` sorts before `b1`.
      expect(await dag.tipFrom('r'), 'a2');
    });

    test('stops on a cycle synced in from a peer', () async {
      await edge('r', 'a2');
      expect(await dag.tipFrom('a1'), 'r');
    });
  });
}
