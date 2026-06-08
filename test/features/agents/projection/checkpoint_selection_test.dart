import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';
import 'package:lotti/features/agents/projection/checkpoint_selection.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import 'projection_test_fixtures.dart';

AgentEvent _ev(
  String id, {
  AgentEventKind kind = AgentEventKind.message,
  List<String> parents = const [],
}) => AgentEvent(
  id: id,
  hostId: 'h0',
  kind: kind,
  causalParents: parents,
  vectorClock: const VectorClock({'h0': 1}),
);

/// Inclusive-ancestor oracle, recomputed in the test independent of the
/// implementation.
Set<String> _ancestors(String id, Map<String, AgentEvent> byId) {
  final out = <String>{};
  final stack = [id];
  while (stack.isNotEmpty) {
    final current = stack.removeLast();
    if (!out.add(current)) continue;
    final event = byId[current];
    if (event == null) continue;
    for (final parent in event.causalParents) {
      if (byId.containsKey(parent)) stack.add(parent);
    }
  }
  return out;
}

/// `k` concurrent summaries (`s0..s{k-1}`) folding the same frontier `e0 ← e1`,
/// all joined by a single head `j` — so every summary is a common ancestor of
/// the only head with identical coverage (3: `{e0, e1, s_i}`). This isolates the
/// equal-coverage tiebreak (`coverage == bestCoverage` → lowest id wins) that a
/// random DAG only stumbles into rarely.
List<AgentEvent> _equalCoverageSummaries(int k) {
  // Ids are emitted in non-sorted order on purpose, so a tiebreak by *position*
  // (a plausible wrong implementation) would disagree with a tiebreak by *id*.
  final summaryIds = [for (var i = k - 1; i >= 0; i--) 's$i'];
  return [
    _ev('e0'),
    _ev('e1', parents: ['e0']),
    for (final id in summaryIds)
      _ev(id, kind: AgentEventKind.summary, parents: ['e1']),
    _ev('j', parents: summaryIds),
  ];
}

void main() {
  group('selectActiveCheckpoint', () {
    // ── generative properties ────────────────────────────────────────────────

    glados.Glados(
      glados.IntAnys(glados.any).intInRange(2, 6),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'equal-coverage concurrent summaries break ties by lowest id',
      (k) {
        final selection = selectActiveCheckpoint(
          canonicalOrder(_equalCoverageSummaries(k)),
        );
        // All k summaries tie on coverage; the lexicographically lowest id wins,
        // regardless of the order they were emitted in.
        expect(selection.activeCheckpointId, 's0', reason: 'k=$k');
        expect(selection.coveredIds, ['e0', 'e1', 's0'], reason: 'k=$k');
        // The join and the other summaries are not verbatim tail (summaries are
        // never tail; the join is uncovered but it is a message → it is tail).
        expect(selection.uncoveredTailIds, ['j'], reason: 'k=$k');
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.projectionDag,
      glados.any.shuffleSeed,
      glados.ExploreConfig(numRuns: 180),
    ).test('is independent of arrival order', (dag, seed) {
      final fromBuild = selectActiveCheckpoint(canonicalOrder(dag.events));
      final fromShuffle = selectActiveCheckpoint(
        canonicalOrder(dag.shuffled(seed)),
      );
      expect(fromShuffle, fromBuild);
    }, tags: 'glados');

    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 180),
    ).test('partitions non-summary events into covered xor tail', (dag) {
      final ordered = canonicalOrder(dag.events);
      final selection = selectActiveCheckpoint(ordered);
      final covered = selection.coveredIds.toSet();
      final tail = selection.uncoveredTailIds.toSet();

      // Covered and tail never overlap.
      expect(covered.intersection(tail), isEmpty);

      // Every non-summary event is either covered or in the tail.
      for (final event in ordered) {
        if (event.kind == AgentEventKind.summary) continue;
        expect(
          covered.contains(event.id) ^ tail.contains(event.id),
          isTrue,
          reason: '${event.id} must be exactly one of covered/tail',
        );
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 180),
    ).test('an active checkpoint is a summary ancestral to every head', (
      dag,
    ) {
      final ordered = canonicalOrder(dag.events);
      final selection = selectActiveCheckpoint(ordered);
      final active = selection.activeCheckpointId;
      if (active == null) return;

      final byId = {for (final e in ordered) e.id: e};
      expect(byId[active]!.kind, AgentEventKind.summary);
      expect(selection.coveredIds, contains(active));

      final projection = project(ordered);
      for (final head in projection.headIds) {
        expect(
          _ancestors(head, byId),
          contains(active),
          reason: 'active checkpoint must precede head $head',
        );
      }
    }, tags: 'glados');

    glados.Glados(
      glados.any.projectionDag,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'the active checkpoint covers the most history among candidates',
      (
        dag,
      ) {
        final ordered = canonicalOrder(dag.events);
        final selection = selectActiveCheckpoint(ordered);
        final active = selection.activeCheckpointId;
        if (active == null) return;

        final byId = {for (final e in ordered) e.id: e};
        final projection = project(ordered);
        // Every summary ancestral to all heads must cover no more than the
        // active one.
        for (final event in ordered) {
          if (event.kind != AgentEventKind.summary) continue;
          final isCommon = projection.headIds.every(
            (h) => _ancestors(h, byId).contains(event.id),
          );
          if (!isCommon) continue;
          expect(
            _ancestors(event.id, byId).length,
            lessThanOrEqualTo(selection.coveredIds.length),
          );
        }
      },
      tags: 'glados',
    );

    // ── examples ─────────────────────────────────────────────────────────────

    test('no summary → no active checkpoint and the whole log is the tail', () {
      final events = canonicalOrder([
        _ev('e0'),
        _ev('e1', parents: ['e0']),
        _ev('e2', parents: ['e1']),
      ]);
      final selection = selectActiveCheckpoint(events);
      expect(selection.activeCheckpointId, isNull);
      expect(selection.coveredIds, isEmpty);
      expect(selection.uncoveredTailIds, ['e0', 'e1', 'e2']);
    });

    test('a summary covers its ancestors; later events form the tail', () {
      final events = canonicalOrder([
        _ev('e0'),
        _ev('e1', parents: ['e0']),
        _ev('e2', kind: AgentEventKind.summary, parents: ['e1']),
        _ev('e3', parents: ['e2']),
      ]);
      final selection = selectActiveCheckpoint(events);
      expect(selection.activeCheckpointId, 'e2');
      expect(selection.coveredIds, ['e0', 'e1', 'e2']);
      expect(selection.uncoveredTailIds, ['e3']);
    });

    test('the deepest summary on the trunk wins', () {
      final events = canonicalOrder([
        _ev('e0', kind: AgentEventKind.summary),
        _ev('e1', parents: ['e0']),
        _ev('e2', kind: AgentEventKind.summary, parents: ['e1']),
        _ev('e3', parents: ['e2']),
      ]);
      final selection = selectActiveCheckpoint(events);
      expect(selection.activeCheckpointId, 'e2');
      expect(selection.coveredIds, ['e0', 'e1', 'e2']);
      expect(selection.uncoveredTailIds, ['e3']);
    });

    test(
      'a fork after a summary keeps it active; the tail spans both branches',
      () {
        final events = canonicalOrder([
          _ev('e0'),
          _ev('e1', kind: AgentEventKind.summary, parents: ['e0']),
          _ev('e2', parents: ['e1']),
          _ev('e3', parents: ['e1']),
        ]);
        final selection = selectActiveCheckpoint(events);
        expect(selection.activeCheckpointId, 'e1');
        expect(selection.coveredIds, ['e0', 'e1']);
        expect(selection.uncoveredTailIds, ['e2', 'e3']);
      },
    );

    test('breaks ties between equal-coverage summaries by lowest id', () {
      // s1 and s2 are concurrent summaries over the same frontier (both fold
      // {e0, e1}); the join e3 makes both ancestral to the single head, so
      // they tie on coverage (3) and the lowest id wins.
      final events = canonicalOrder([
        _ev('e0'),
        _ev('e1', parents: ['e0']),
        _ev('s1', kind: AgentEventKind.summary, parents: ['e1']),
        _ev('s2', kind: AgentEventKind.summary, parents: ['e1']),
        _ev('e3', parents: ['s1', 's2']),
      ]);
      final selection = selectActiveCheckpoint(events);
      expect(selection.activeCheckpointId, 's1');
      expect(selection.coveredIds, ['e0', 'e1', 's1']);
    });

    test('a summary on only one branch is not selected', () {
      final events = canonicalOrder([
        _ev('e0'),
        _ev('e1', parents: ['e0']),
        _ev('e2', kind: AgentEventKind.summary, parents: ['e1']),
        _ev('e3', parents: ['e1']),
      ]);
      final selection = selectActiveCheckpoint(events);
      expect(selection.activeCheckpointId, isNull);
      // e2 is a summary, so it is never part of the verbatim tail.
      expect(selection.uncoveredTailIds, ['e0', 'e1', 'e3']);
    });
  });
}
