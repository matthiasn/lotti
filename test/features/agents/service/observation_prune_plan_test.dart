import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/service/observation_prune_plan.dart';
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  final cutoff = DateTime.utc(2026, 6);
  final old = DateTime.utc(2026, 5);
  final older = DateTime.utc(2026, 4);
  final oldest = DateTime.utc(2026, 3);
  final young = DateTime.utc(2026, 7);

  PrunableMessage msg(
    String id,
    DateTime createdAt, {
    bool observation = true,
    List<String> parents = const [],
  }) => PrunableMessage(
    id: id,
    createdAt: createdAt,
    isObservation: observation,
    parentIds: parents,
  );

  ObservationPrunePlan plan(
    List<PrunableMessage> messages, {
    Set<String> protectedIds = const {},
    int limit = 100,
  }) => planObservationPrune(
    messages: messages,
    cutoff: cutoff,
    protectedIds: protectedIds,
    limit: limit,
  );

  /// Rebuilds the projection over the messages a plan would leave behind,
  /// dropping every `messagePrev` edge that points into the deleted set —
  /// which is exactly what the sweep does to the link rows.
  AgentProjection projectSurvivors(
    List<PrunableMessage> messages,
    ObservationPrunePlan pruned,
  ) {
    final gone = pruned.messageIds.toSet();
    return project([
      for (final message in messages)
        if (!gone.contains(message.id))
          AgentEvent(
            id: message.id,
            hostId: 'host',
            vectorClock: const VectorClock({'host': 1}),
            kind: AgentEventKind.message,
            causalParents: [
              for (final parentId in message.parentIds)
                if (!gone.contains(parentId)) parentId,
            ],
          ),
    ]);
  }

  group('ancestor closure', () {
    test('prunes a whole old prefix and leaves one head', () {
      final messages = [
        msg('a', oldest),
        msg('b', older, parents: ['a']),
        msg('c', young, parents: ['b']),
      ];

      final pruned = plan(messages);

      expect(pruned.messageIds, ['a', 'b']);
      final projection = projectSurvivors(messages, pruned);
      expect(projection.headIds, ['c']);
      expect(
        projection.danglingParentIds,
        isEmpty,
        reason:
            'Dropping the edge into the deleted set is what keeps '
            'viewComplete true, so fork healing keeps working.',
      );
    });

    test('stops at a summary rather than reaching past it', () {
      // a <- b(summary) <- c: `c` is an old observation, but deleting it
      // would orphan `b` into a second head.
      final messages = [
        msg('a', oldest),
        msg('b', older, observation: false, parents: ['a']),
        msg('c', old, parents: ['b']),
        msg('d', young, parents: ['c']),
      ];

      final pruned = plan(messages);

      expect(
        pruned.messageIds,
        ['a'],
        reason: 'Only the prefix below the summary is ancestor-closed.',
      );
      expect(projectSurvivors(messages, pruned).headIds, ['d']);
    });

    test('a mid-chain delete would fork — and is not planned', () {
      final messages = [
        msg('a', oldest, observation: false),
        msg('b', older, parents: ['a']),
        msg('c', young, parents: ['b']),
      ];

      final pruned = plan(messages);

      // Proof the guard matters: deleting `b` alone resurrects `a` as a head.
      final ifWePrunedB = projectSurvivors(
        messages,
        const ObservationPrunePlan(messageIds: ['b']),
      );
      expect(ifWePrunedB.headIds, ['a', 'c']);

      expect(pruned.messageIds, isEmpty);
      expect(projectSurvivors(messages, pruned).headIds, ['c']);
    });

    test('a young parent blocks its old child', () {
      // Wall-clock and causal order diverge across devices, so the cutoff
      // alone would select `b` while its parent stays.
      final messages = [
        msg('a', young),
        msg('b', old, parents: ['a']),
      ];

      expect(plan(messages).messageIds, isEmpty);
    });

    test('prunes a join only once both branches are prunable', () {
      final messages = [
        msg('l', oldest),
        msg('r', oldest),
        msg('j', older, parents: ['l', 'r']),
        msg('tip', young, parents: ['j']),
      ];

      final pruned = plan(messages);

      expect(pruned.messageIds.toSet(), {'l', 'r', 'j'});
      expect(
        pruned.messageIds.indexOf('j'),
        greaterThan(pruned.messageIds.indexOf('l')),
        reason: 'A join must be emitted after both of its parents.',
      );
      expect(projectSurvivors(messages, pruned).headIds, ['tip']);
    });

    test('one unprunable branch of a join holds the join back', () {
      final messages = [
        msg('l', oldest),
        msg('r', young),
        msg('j', older, parents: ['l', 'r']),
      ];

      expect(
        plan(messages).messageIds,
        ['l'],
        reason: 'Pruning `j` would strand `r` as a head.',
      );
    });
  });

  group('protected ids', () {
    test('the live head survives even when the whole thread is old', () {
      final messages = [
        msg('a', oldest),
        msg('b', older, parents: ['a']),
        msg('head', old, parents: ['b']),
      ];

      final pruned = plan(messages, protectedIds: {'head'});

      expect(pruned.messageIds, ['a', 'b']);
      expect(
        projectSurvivors(messages, pruned).headIds,
        ['head'],
        reason:
            'agentState.recentHeadMessageId must never point at a deleted row.',
      );
    });

    test('nothing downstream of a protected id is pruned either', () {
      final messages = [
        msg('a', oldest),
        msg('keep', older, parents: ['a']),
        msg('c', old, parents: ['keep']),
      ];

      expect(plan(messages, protectedIds: {'keep'}).messageIds, ['a']);
    });

    test('an unprotected all-old thread is emptied', () {
      // Nothing points into this thread any more, so there is no tip to keep.
      final messages = [
        msg('a', oldest),
        msg('b', older, parents: ['a']),
      ];

      expect(plan(messages).messageIds, ['a', 'b']);
    });
  });

  group('bounds and malformed logs', () {
    test('a truncated plan is still ancestor-closed', () {
      final messages = [
        msg('a', oldest),
        msg('b', older, parents: ['a']),
        msg('c', old, parents: ['b']),
        msg('tip', young, parents: ['c']),
      ];

      final pruned = plan(messages, limit: 2);

      expect(pruned.messageIds, ['a', 'b']);
      expect(
        projectSurvivors(messages, pruned).headIds,
        ['tip'],
        reason: 'A partial sweep must leave the DAG as sound as a full one.',
      );
    });

    test('an absent parent blocks the prune rather than licensing it', () {
      // A messagePrev link can sync before the entity it points at, so a
      // parent still in flight looks exactly like one an earlier sweep took.
      // Guessing "gone" deletes `b`, drops the edge, and forks the moment the
      // real parent lands.
      final messages = [
        msg('b', older, parents: ['still-in-flight']),
        msg('c', young, parents: ['b']),
      ];

      expect(plan(messages).messageIds, isEmpty);
    });

    test('a genuinely pruned parent leaves no edge, so the child is free', () {
      // The sweep deletes the edges into whatever it deletes, so a row an
      // earlier pass really did take is a parentless root here — not a
      // dangling reference.
      final messages = [
        msg('b', older),
        msg('c', young, parents: ['b']),
      ];

      expect(plan(messages).messageIds, ['b']);
    });

    test('a cycle is refused rather than reasoned about', () {
      final messages = [
        msg('a', oldest, parents: ['b']),
        msg('b', older, parents: ['a']),
      ];

      expect(plan(messages).messageIds, isEmpty);
    });

    test('a self-referencing message is refused', () {
      expect(
        plan([
          msg('a', oldest, parents: ['a']),
        ]).messageIds,
        isEmpty,
      );
    });

    test('the plan is deterministic across input orderings', () {
      final messages = [
        msg('a', oldest),
        msg('b', older, parents: ['a']),
        msg('tip', young, parents: ['b']),
      ];

      expect(
        plan(messages.reversed.toList()).messageIds,
        plan(messages).messageIds,
        reason: 'Two devices with the same log must plan the same delete.',
      );
    });
  });

  group('properties', () {
    /// Builds a deterministic pseudo-random DAG from two seeds: every message
    /// links only to earlier ones, so the graph is acyclic by construction and
    /// the properties below are about the planner, not the generator.
    List<PrunableMessage> dag(int shapeSeed, int kindSeed) {
      final messages = <PrunableMessage>[];
      var shape = shapeSeed | 1;
      var kinds = kindSeed | 1;
      for (var i = 0; i < 12; i++) {
        shape = (shape * 1103515245 + 12345) & 0x7fffffff;
        kinds = (kinds * 1103515245 + 12345) & 0x7fffffff;
        final parents = <String>[];
        if (i > 0) {
          parents.add('m${shape % i}');
          if (shape % 5 == 0 && i > 1) {
            final second = 'm${(shape ~/ 7) % i}';
            if (second != parents.first) parents.add(second);
          }
        }
        messages.add(
          PrunableMessage(
            id: 'm$i',
            // Ages deliberately out of causal order: the planner must not
            // lean on timestamps agreeing with the graph.
            createdAt: DateTime.utc(2026, 1, 1 + (shape % 20)),
            isObservation: kinds % 3 != 0,
            parentIds: parents,
          ),
        );
      }
      return messages;
    }

    Set<String> headsOf(List<PrunableMessage> messages, Set<String> gone) {
      final referenced = <String>{};
      for (final message in messages) {
        if (gone.contains(message.id)) continue;
        for (final parentId in message.parentIds) {
          if (!gone.contains(parentId)) referenced.add(parentId);
        }
      }
      return {
        for (final message in messages)
          if (!gone.contains(message.id) && !referenced.contains(message.id))
            message.id,
      };
    }

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(1, 5000),
      glados.IntAnys(glados.any).intInRange(1, 5000),
      glados.ExploreConfig(numRuns: 200),
    ).test('pruning never adds a head, and is ancestor-closed', (a, b) {
      final messages = dag(a, b);
      final planned = planObservationPrune(
        messages: messages,
        cutoff: DateTime.utc(2026, 1, 15),
        protectedIds: const {},
        limit: 100,
      ).messageIds;
      final gone = planned.toSet();

      // Ancestor-closure: a planned message's parents are planned too.
      final byId = {for (final m in messages) m.id: m};
      for (final id in planned) {
        for (final parentId in byId[id]!.parentIds) {
          expect(
            gone.contains(parentId),
            isTrue,
            reason: '$id was planned while its parent $parentId survives',
          );
        }
      }

      // The head set never grows — a fork is exactly what must not appear.
      final before = headsOf(messages, const {});
      final after = headsOf(messages, gone);
      expect(
        after.difference(before),
        isEmpty,
        reason: 'pruning manufactured head(s) ${after.difference(before)}',
      );
    }, tags: 'glados');

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(1, 5000),
      glados.IntAnys(glados.any).intInRange(1, 5000),
      glados.ExploreConfig(numRuns: 200),
    ).test('the plan is independent of input order', (a, b) {
      final messages = dag(a, b);
      List<String> planFor(List<PrunableMessage> input) => planObservationPrune(
        messages: input,
        cutoff: DateTime.utc(2026, 1, 15),
        protectedIds: const {},
        limit: 100,
      ).messageIds;

      // Two devices holding the same log must plan the same delete.
      expect(planFor(messages.reversed.toList()), planFor(messages));
    }, tags: 'glados');

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(1, 5000),
      glados.IntAnys(glados.any).intInRange(1, 5000),
      glados.ExploreConfig(numRuns: 200),
    ).test('a protected id and its descendants are never planned', (a, b) {
      final messages = dag(a, b);
      final plan = planObservationPrune(
        messages: messages,
        cutoff: DateTime.utc(2026, 1, 15),
        protectedIds: const {'m6'},
        limit: 100,
      ).messageIds;

      expect(plan, isNot(contains('m6')));
      // Anything reachable from m6 upward stays too: its own ancestors may go,
      // but nothing that has m6 as an ancestor may.
      final byId = {for (final m in messages) m.id: m};
      bool descendsFromProtected(String id, [int depth = 0]) {
        if (depth > 12) return false;
        final parents = byId[id]?.parentIds ?? const [];
        return parents.contains('m6') ||
            parents.any((p) => descendsFromProtected(p, depth + 1));
      }

      for (final id in plan) {
        expect(descendsFromProtected(id), isFalse, reason: '$id descends m6');
      }
    }, tags: 'glados');
  });
}
