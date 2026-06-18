/// Deterministic ego-network layout for the knowledge-graph POC.
///
/// Strategy (ADR 0029 Decision 1/3): this is NOT a free force-directed
/// hairball. The focus node is pinned at the origin; its neighbors are seeded
/// into relation-class *sectors* (project above, linked tasks to the side, log
/// entries below, AI provenance upper-left, rating upper-right, checklist
/// lower-right), and a short Fruchterman–Reingold relaxation only declutters
/// overlaps while preserving that structure. Deterministic via a seeded PRNG so
/// screenshots are reproducible.
///
/// At ego scale (tens of nodes) O(n²) repulsion is trivial; a Barnes–Hut
/// quadtree is the documented path for the larger "Stargazer" graphs and is not
/// needed here.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Offset;
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';

/// Computed world-space positions, origin-centered.
class GraphLayout {
  const GraphLayout(this.positions);

  final Map<String, Offset> positions;
}

const double _ring1 = 225; // focus → 1-hop neighbor distance
const double _ring2 = 104; // parent → child (e.g. checklist → item)

/// Sector angle (radians; 0 = right, +y = down) for a 1-hop neighbor, chosen by
/// relation class and node type so each kind of relationship lives in its own
/// region of the ego-network.
double _baseSector(GraphScenario scenario, GraphNode node) {
  GraphEdgeKind? kind;
  for (final e in scenario.edges) {
    final touchesFocus =
        (e.fromId == scenario.seedId && e.toId == node.id) ||
        (e.toId == scenario.seedId && e.fromId == node.id);
    if (touchesFocus) {
      kind = e.kind;
      break;
    }
  }
  switch (kind) {
    case GraphEdgeKind.containment:
      return -math.pi / 2; // top
    case GraphEdgeKind.provenance:
      return -2.45; // upper-left
    case GraphEdgeKind.evaluation:
      return -0.6; // upper-right
    case GraphEdgeKind.checklist:
      return 0.95; // lower-right
    case GraphEdgeKind.association:
    case null:
      switch (node.type) {
        case GraphNodeType.task:
          return 0.15; // right — linked tasks
        case GraphNodeType.checklist:
          return 0.95; // lower-right
        // ignore: no_default_cases
        default:
          return math.pi / 2 + 0.25; // bottom — log/timeline entries
      }
  }
}

/// Lay out [scenario] into origin-centered world coordinates.
GraphLayout computeGraphLayout(
  GraphScenario scenario, {
  int seed = 7,
  int iterations = 260,
}) {
  final rng = math.Random(seed);
  final ids = scenario.nodes.map((n) => n.id).toList();

  // Undirected adjacency.
  final adj = {for (final id in ids) id: <String>[]};
  for (final e in scenario.edges) {
    adj[e.fromId]?.add(e.toId);
    adj[e.toId]?.add(e.fromId);
  }

  // BFS for hop distance + parent from the focus.
  final hop = <String, int>{scenario.seedId: 0};
  final parent = <String, String>{};
  final queue = <String>[scenario.seedId];
  var head = 0;
  while (head < queue.length) {
    final cur = queue[head++];
    for (final nb in adj[cur] ?? const <String>[]) {
      if (!hop.containsKey(nb)) {
        hop[nb] = hop[cur]! + 1;
        parent[nb] = cur;
        queue.add(nb);
      }
    }
  }

  final pos = <String, Offset>{scenario.seedId: Offset.zero};

  // Seed 1-hop neighbors into their relation sectors, fanning out members that
  // share a sector.
  final oneHop = ids.where((id) => hop[id] == 1).toList();
  final buckets = <double, List<String>>{};
  for (final id in oneHop) {
    final base = _baseSector(scenario, scenario.nodeById(id));
    buckets.putIfAbsent(base, () => []).add(id);
  }
  buckets.forEach((base, members) {
    final n = members.length;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.0 : (i / (n - 1) - 0.5) * 2; // -1..1
      final angle = base + t * 0.95;
      pos[members[i]] = Offset(
        math.cos(angle) * _ring1,
        math.sin(angle) * _ring1,
      );
    }
  });

  // Seed deeper nodes (checklist items) around their parent, fanned outward.
  final deep = ids.where((id) => (hop[id] ?? 9) >= 2).toList();
  final byParent = <String, List<String>>{};
  for (final id in deep) {
    byParent.putIfAbsent(parent[id] ?? scenario.seedId, () => []).add(id);
  }
  byParent.forEach((par, members) {
    final pp = pos[par] ?? Offset.zero;
    final outward = math.atan2(pp.dy, pp.dx);
    final n = members.length;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.0 : (i / (n - 1) - 0.5) * 2;
      final angle = outward + t * 0.9;
      pos[members[i]] =
          pp + Offset(math.cos(angle) * _ring2, math.sin(angle) * _ring2);
    }
  });

  // Any stragglers (disconnected) get a small deterministic jitter.
  for (final id in ids) {
    pos.putIfAbsent(
      id,
      () => Offset(
        (rng.nextDouble() - 0.5) * 120,
        (rng.nextDouble() - 0.5) * 120,
      ),
    );
  }

  _relax(scenario, ids, pos, rng, iterations, pinned: scenario.seedId);
  return GraphLayout(pos);
}

/// General force-directed layout over a whole connected "world" graph (no
/// single ego focus): random seed positions + a longer relaxation with stronger
/// repulsion, so linked clusters separate into explorable regions. Deterministic.
GraphLayout computeWorldLayout(
  GraphScenario scenario, {
  int seed = 11,
  int iterations = 620,
}) {
  final rng = math.Random(seed);
  final ids = scenario.nodes.map((n) => n.id).toList();
  final spread = 150.0 * math.sqrt(ids.length.toDouble());
  final pos = <String, Offset>{
    for (final id in ids)
      id: Offset(
        (rng.nextDouble() - 0.5) * spread,
        (rng.nextDouble() - 0.5) * spread,
      ),
  };
  _relax(
    scenario,
    ids,
    pos,
    rng,
    iterations,
    repulsion: 26000,
    gravity: 0.0025,
    initialTemp: 110,
  );
  return GraphLayout(pos);
}

double _idealLength(GraphEdgeKind kind) {
  switch (kind) {
    case GraphEdgeKind.checklist:
      return 92;
    case GraphEdgeKind.containment:
      return 165;
    case GraphEdgeKind.evaluation:
      return 150;
    case GraphEdgeKind.provenance:
    case GraphEdgeKind.association:
      return 175;
  }
}

/// Short Fruchterman–Reingold pass: declutter without destroying the seeded
/// structure. The focus node stays pinned at the origin.
void _relax(
  GraphScenario scenario,
  List<String> ids,
  Map<String, Offset> pos,
  math.Random rng,
  int iterations, {
  String? pinned,
  double repulsion = 14000,
  double gravity = 0.008,
  double initialTemp = 70,
}) {
  const spring = 0.06;
  var temp = initialTemp;

  for (var it = 0; it < iterations; it++) {
    final disp = {for (final id in ids) id: Offset.zero};

    // Repulsion between every pair.
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        final a = ids[i];
        final b = ids[j];
        var delta = pos[a]! - pos[b]!;
        var dist = delta.distance;
        if (dist < 0.01) {
          delta = Offset(rng.nextDouble() - 0.5, rng.nextDouble() - 0.5);
          dist = delta.distance.clamp(0.01, double.infinity);
        }
        final force = repulsion / (dist * dist);
        final dir = delta / dist;
        disp[a] = disp[a]! + dir * force;
        disp[b] = disp[b]! - dir * force;
      }
    }

    // Spring attraction along edges, toward each kind's ideal length.
    for (final e in scenario.edges) {
      final pa = pos[e.fromId];
      final pb = pos[e.toId];
      if (pa == null || pb == null) continue;
      final delta = pa - pb;
      var dist = delta.distance;
      if (dist < 0.01) dist = 0.01;
      final force = (dist - _idealLength(e.kind)) * spring;
      final dir = delta / dist;
      disp[e.fromId] = disp[e.fromId]! - dir * force;
      disp[e.toId] = disp[e.toId]! + dir * force;
    }

    // Weak gravity toward the origin keeps the ego-network compact.
    for (final id in ids) {
      disp[id] = disp[id]! - pos[id]! * gravity;
    }

    // Apply, capped by the cooling temperature; a pinned node stays fixed.
    for (final id in ids) {
      if (pinned != null && id == pinned) continue;
      final d = disp[id]!;
      final len = d.distance;
      final capped = len > temp ? d / len * temp : d;
      pos[id] = pos[id]! + capped;
    }
    temp = math.max(temp * 0.985, 4);
  }
}
