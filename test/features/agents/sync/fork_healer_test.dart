import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/join_plan.dart';
import 'package:lotti/features/agents/sync/fork_healer.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';
import 'fork_test_support.dart';
import 'in_memory_agent_repository.dart';

const _agentId = 'agent-1';

void main() {
  setUpAll(registerAllFallbackValues);

  late InMemoryAgentRepository repo;
  late ForkHealer healer;

  setUp(() {
    if (!getIt.isRegistered<DomainLogger>()) {
      getIt.registerSingleton<DomainLogger>(MockDomainLogger());
    }
    final bench = makeForkBench();
    repo = bench.repo;
    healer = bench.healer;
  });

  List<String> headsOf() => headsOfLog(repo.messages, repo.links);

  void seedAgent({String? head}) {
    repo.seed([
      makeTestState(agentId: _agentId).copyWith(recentHeadMessageId: head),
    ]);
  }

  void seedMessage(String id, {DateTime? at}) {
    repo.seed([
      makeTestMessage(
        id: id,
        agentId: _agentId,
        createdAt: at ?? DateTime(2024),
      ),
    ]);
  }

  Future<void> edge(String child, String parent) => repo.upsertLink(
    AgentLink.messagePrev(
      id: 'mp-$child-$parent',
      fromId: child,
      toId: parent,
      createdAt: DateTime(2024, 1, 2),
      updatedAt: DateTime(2024, 1, 2),
      vectorClock: null,
    ),
  );

  Future<String?> heal() => healer.maybeHealFork(
    agentId: _agentId,
    at: DateTime(2024, 2),
    runKey: 'rk',
  );

  test('heals a surviving fork into a single head', () async {
    await seedForkInto(repo, head: 'b');
    expect(headsOf().toSet(), {'a', 'b'}); // precondition

    final joinId = await heal();
    expect(joinId, computeJoinId(['a', 'b']));
    expect(headsOf(), [joinId]);
    final state = await repo.getAgentState(_agentId);
    expect(state!.recentHeadMessageId, joinId);
  });

  test('no-op on a single-head (linear) log', () async {
    seedAgent(head: 'b');
    seedMessage('p');
    seedMessage('a', at: DateTime(2024, 1, 2));
    seedMessage('b', at: DateTime(2024, 1, 3));
    await edge('a', 'p');
    await edge('b', 'a'); // p ← a ← b : a single head
    expect(headsOf(), ['b']);

    expect(await heal(), isNull);
    expect(repo.messages.length, 3); // no join appended
  });

  test('no-op with fewer than two messages', () async {
    seedAgent();
    seedMessage('only');
    expect(await heal(), isNull);
    expect(repo.messages.length, 1);
  });

  test('defers when the view is incomplete (a dangling parent)', () async {
    // a and b both point at a parent p that has not synced yet ⇒ dangling.
    seedAgent(head: 'b');
    seedMessage('a');
    seedMessage('b');
    await edge('a', 'p'); // p absent locally
    await edge('b', 'p');
    expect(await heal(), isNull); // viewComplete == false ⇒ defer
    expect(repo.messages.length, 2);
  });

  test('is idempotent — a second heal neither re-forks nor re-emits', () async {
    await seedForkInto(repo, head: 'b');
    final joinId = await heal();
    expect(headsOf(), [joinId]);

    // The fork is gone (single head), so a re-run does nothing — and crucially
    // never appends a second node off a now-joined parent (no re-fork).
    expect(await heal(), isNull);
    expect(repo.messages.where((m) => m.id == joinId).length, 1);
    expect(headsOf(), [joinId]);
  });

  test(
    'is non-fatal on a corrupt log (a cycle) — skips without throwing',
    () async {
      seedAgent(head: 'b');
      seedMessage('a');
      seedMessage('b');
      await edge('a', 'b');
      await edge('b', 'a'); // a ⇄ b cycle ⇒ canonicalOrder throws
      expect(await heal(), isNull); // caught and skipped
      expect(repo.messages.length, 2); // nothing appended
    },
  );

  // ── multi-device convergence (ADR 0018 rule 8) ─────────────────────────────
  group('multi-device convergence', () {
    test(
      'two devices heal the same fork to one node; the union has one head',
      () async {
        // Different hosts ⇒ each stamps its own envelope on the same join.
        final a = makeForkBench(host: 'hostA');
        final c = makeForkBench(host: 'hostC');
        await seedForkInto(a.repo, head: 'a');
        await seedForkInto(c.repo, head: 'b');

        final jA = await a.healer.maybeHealFork(
          agentId: _agentId,
          at: DateTime(2024, 2),
        );
        final jC = await c.healer.maybeHealFork(
          agentId: _agentId,
          at: DateTime(2024, 2),
        );
        expect(jA, isNotNull);
        expect(jA, jC); // same head set ⇒ same content-addressed join id

        // Each device stamped its own envelope (hostA vs hostC), but the synced
        // union holds exactly one join node (p, a, b, join = 4) and one head.
        final unionMessageIds = {
          for (final m in [...a.repo.messages, ...c.repo.messages]) m.id,
        };
        expect(unionMessageIds, {'p', 'a', 'b', jA});
        expect(projectDeviceUnion([a.repo, c.repo]).headIds, [jA]);
      },
    );

    test('the converged projection is independent of merge order', () async {
      final a = makeForkBench(host: 'hostA');
      final c = makeForkBench(host: 'hostC');
      await seedForkInto(a.repo, head: 'a');
      await seedForkInto(c.repo, head: 'b');
      await a.healer.maybeHealFork(agentId: _agentId, at: DateTime(2024, 2));
      await c.healer.maybeHealFork(agentId: _agentId, at: DateTime(2024, 2));

      // The whole derived projection — heads, dangling parents, latest report —
      // is identical regardless of which device's log is folded first.
      expect(
        projectDeviceUnion([a.repo, c.repo]),
        projectDeviceUnion([c.repo, a.repo]),
      );
    });

    test(
      'repeated concurrent forks stay bounded — every heal returns to one head',
      () async {
        final d = makeForkBench(host: 'hostA');
        d.repo.seed([
          makeTestState(agentId: _agentId).copyWith(recentHeadMessageId: 'g'),
          makeTestMessage(
            id: 'g',
            agentId: _agentId,
            createdAt: DateTime(2024),
          ),
        ]);

        var head = 'g';
        for (var round = 1; round <= 3; round++) {
          // Two devices append concurrently off the shared head ⇒ a 2-head fork.
          d.repo.seed([
            for (final tip in ['a$round', 'b$round'])
              makeTestMessage(
                id: tip,
                agentId: _agentId,
                createdAt: DateTime(2024, 1, round + 1),
              ),
          ]);
          for (final tip in ['a$round', 'b$round']) {
            await d.repo.upsertLink(
              AgentLink.messagePrev(
                id: 'mp-$tip-$head',
                fromId: tip,
                toId: head,
                createdAt: DateTime(2024, 1, round + 1),
                updatedAt: DateTime(2024, 1, round + 1),
                vectorClock: null,
              ),
            );
          }
          expect(headsOfLog(d.repo.messages, d.repo.links).length, 2);

          final j = await d.healer.maybeHealFork(
            agentId: _agentId,
            at: DateTime(2024, 2, round),
          );
          expect(j, isNotNull);
          // collapses back to one head each round.
          expect(headsOfLog(d.repo.messages, d.repo.links), [j]);
          head = j!;
        }

        // No storm: genesis + 2 tips/round + 1 join/round over 3 rounds = 10.
        expect(d.repo.messages.length, 1 + 3 * (2 + 1));
      },
    );
  });
}
