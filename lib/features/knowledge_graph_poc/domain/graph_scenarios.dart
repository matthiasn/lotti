/// Deterministic synthetic scenarios for the knowledge-graph POC.
///
/// Each scenario is a task ego-network — the view the user asked for: open a
/// task and see its linked timeline entries, linked tasks, project, AI output,
/// rating and checklist. Times are spread relative to a fixed [_now] so the
/// recency-as-luminance encoding has something to show.
library;

import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';

/// Canonical synthetic category ids, in palette order (see `GraphStyle`).
const String catWork = 'work';
const String catWriting = 'writing';
const String catHealth = 'health';
const String catLearning = 'learning';
const String catHome = 'home';
const String catAdmin = 'admin';

/// Ordered for stable color assignment.
const List<String> categoryOrder = [
  catWork,
  catWriting,
  catHealth,
  catLearning,
  catHome,
  catAdmin,
];

final DateTime _now = DateTime(2026, 6, 18, 9);

DateTime _daysAgo(double days) =>
    _now.subtract(Duration(minutes: (days * 24 * 60).round()));

/// The headline scenario: a realistic, balanced task ego-network (~20 nodes).
GraphScenario taskEgoNetworkScenario() {
  const seed = 't0';
  final nodes = <GraphNode>[
    GraphNode(
      id: seed,
      type: GraphNodeType.task,
      label: 'Ship v2.3 release',
      categoryId: catWork,
      createdAt: _daysAgo(12),
    ),
    // Containment: the project this task belongs to.
    GraphNode(
      id: 'p0',
      type: GraphNodeType.project,
      label: 'Lotti 2.x',
      categoryId: catWork,
      createdAt: _daysAgo(64),
    ),
    // Linked tasks.
    GraphNode(
      id: 't1',
      type: GraphNodeType.task,
      label: 'Fix sync race condition',
      categoryId: catWork,
      createdAt: _daysAgo(9),
    ),
    GraphNode(
      id: 't2',
      type: GraphNodeType.task,
      label: 'Write release notes',
      categoryId: catWriting,
      createdAt: _daysAgo(5),
    ),
    GraphNode(
      id: 't3',
      type: GraphNodeType.task,
      label: 'Refresh App Store shots',
      categoryId: catWork,
      createdAt: _daysAgo(3),
    ),
    // Timeline / log entries.
    GraphNode(
      id: 'l1',
      type: GraphNodeType.textEntry,
      label: 'Standup notes',
      categoryId: catWork,
      createdAt: _daysAgo(2),
    ),
    GraphNode(
      id: 'l2',
      type: GraphNodeType.audioEntry,
      label: 'Voice memo: rollout plan',
      categoryId: catWork,
      createdAt: _daysAgo(4),
    ),
    GraphNode(
      id: 'l3',
      type: GraphNodeType.textEntry,
      label: 'Bug triage',
      categoryId: catWork,
      createdAt: _daysAgo(7),
    ),
    GraphNode(
      id: 'l4',
      type: GraphNodeType.imageEntry,
      label: 'Crash screenshot',
      categoryId: catWork,
      createdAt: _daysAgo(6),
    ),
    GraphNode(
      id: 'l5',
      type: GraphNodeType.audioEntry,
      label: 'Call with QA',
      categoryId: catWork,
      createdAt: _daysAgo(1),
    ),
    // AI provenance.
    GraphNode(
      id: 'a1',
      type: GraphNodeType.aiResponse,
      label: 'Task summary',
      categoryId: catWork,
      createdAt: _daysAgo(2),
    ),
    GraphNode(
      id: 'a2',
      type: GraphNodeType.aiResponse,
      label: 'Suggested checklist',
      categoryId: catWork,
      createdAt: _daysAgo(8),
    ),
    // Evaluation.
    GraphNode(
      id: 'r1',
      type: GraphNodeType.rating,
      label: 'Effort 4/5',
      categoryId: catWork,
      createdAt: _daysAgo(1),
    ),
    // Checklist + items.
    GraphNode(
      id: 'c1',
      type: GraphNodeType.checklist,
      label: 'Release checklist',
      categoryId: catWork,
      createdAt: _daysAgo(11),
    ),
    GraphNode(
      id: 'ci1',
      type: GraphNodeType.checklistItem,
      label: 'Tag build',
      categoryId: catWork,
      createdAt: _daysAgo(11),
    ),
    GraphNode(
      id: 'ci2',
      type: GraphNodeType.checklistItem,
      label: 'Smoke test',
      categoryId: catWork,
      createdAt: _daysAgo(6),
    ),
    GraphNode(
      id: 'ci3',
      type: GraphNodeType.checklistItem,
      label: 'Notify users',
      categoryId: catWork,
      createdAt: _daysAgo(3),
    ),
    GraphNode(
      id: 'ci4',
      type: GraphNodeType.checklistItem,
      label: 'Publish',
      categoryId: catWork,
      createdAt: _daysAgo(1),
    ),
  ];

  final edges = <GraphEdge>[
    const GraphEdge(fromId: 'p0', toId: seed, kind: GraphEdgeKind.containment),
    for (final t in ['t1', 't2', 't3'])
      GraphEdge(fromId: seed, toId: t, kind: GraphEdgeKind.association),
    for (final l in ['l1', 'l2', 'l3', 'l4', 'l5'])
      GraphEdge(fromId: seed, toId: l, kind: GraphEdgeKind.association),
    const GraphEdge(fromId: 'a1', toId: seed, kind: GraphEdgeKind.provenance),
    const GraphEdge(fromId: 'a2', toId: seed, kind: GraphEdgeKind.provenance),
    const GraphEdge(fromId: 'r1', toId: seed, kind: GraphEdgeKind.evaluation),
    const GraphEdge(fromId: seed, toId: 'c1', kind: GraphEdgeKind.association),
    for (final ci in ['ci1', 'ci2', 'ci3', 'ci4'])
      GraphEdge(fromId: 'c1', toId: ci, kind: GraphEdgeKind.checklist),
  ];

  return GraphScenario(
    name: 'Task ego-network',
    seedId: seed,
    nodes: nodes,
    edges: edges,
    now: _now,
  );
}

/// A busy task: many log entries + a long checklist (hub-collapse motivation).
GraphScenario busyTaskScenario() {
  const seed = 'b0';
  final nodes = <GraphNode>[
    GraphNode(
      id: seed,
      type: GraphNodeType.task,
      label: 'Quarterly planning',
      categoryId: catWork,
      createdAt: _daysAgo(30),
    ),
    GraphNode(
      id: 'bp',
      type: GraphNodeType.project,
      label: 'Operations',
      categoryId: catAdmin,
      createdAt: _daysAgo(120),
    ),
    GraphNode(
      id: 'br',
      type: GraphNodeType.rating,
      label: 'Effort 5/5',
      categoryId: catWork,
      createdAt: _daysAgo(2),
    ),
    GraphNode(
      id: 'ba',
      type: GraphNodeType.aiResponse,
      label: 'Meeting digest',
      categoryId: catWork,
      createdAt: _daysAgo(3),
    ),
    GraphNode(
      id: 'bc',
      type: GraphNodeType.checklist,
      label: 'Agenda',
      categoryId: catWork,
      createdAt: _daysAgo(28),
    ),
  ];
  final edges = <GraphEdge>[
    const GraphEdge(fromId: 'bp', toId: seed, kind: GraphEdgeKind.containment),
    const GraphEdge(fromId: 'br', toId: seed, kind: GraphEdgeKind.evaluation),
    const GraphEdge(fromId: 'ba', toId: seed, kind: GraphEdgeKind.provenance),
    const GraphEdge(fromId: seed, toId: 'bc', kind: GraphEdgeKind.association),
  ];

  // 12 linked tasks + 12 log entries + 6 checklist items.
  const linkedTaskCats = [catWork, catWriting, catHealth, catLearning, catHome];
  for (var i = 0; i < 12; i++) {
    final id = 'bt$i';
    nodes.add(
      GraphNode(
        id: id,
        type: GraphNodeType.task,
        label: 'Workstream ${i + 1}',
        categoryId: linkedTaskCats[i % linkedTaskCats.length],
        createdAt: _daysAgo(4.0 + i),
      ),
    );
    edges.add(
      GraphEdge(fromId: seed, toId: id, kind: GraphEdgeKind.association),
    );
  }
  const logTypes = [
    GraphNodeType.textEntry,
    GraphNodeType.audioEntry,
    GraphNodeType.imageEntry,
  ];
  for (var i = 0; i < 12; i++) {
    final id = 'bl$i';
    nodes.add(
      GraphNode(
        id: id,
        type: logTypes[i % logTypes.length],
        label: 'Note ${i + 1}',
        categoryId: catWork,
        createdAt: _daysAgo(0.5 + i * 1.5),
      ),
    );
    edges.add(
      GraphEdge(fromId: seed, toId: id, kind: GraphEdgeKind.association),
    );
  }
  for (var i = 0; i < 6; i++) {
    final id = 'bci$i';
    nodes.add(
      GraphNode(
        id: id,
        type: GraphNodeType.checklistItem,
        label: 'Item ${i + 1}',
        categoryId: catWork,
        createdAt: _daysAgo(2.0 + i),
      ),
    );
    edges.add(GraphEdge(fromId: 'bc', toId: id, kind: GraphEdgeKind.checklist));
  }

  return GraphScenario(
    name: 'Busy task',
    seedId: seed,
    nodes: nodes,
    edges: edges,
    now: _now,
  );
}

/// A light task: proves the view does not look empty at small scale.
GraphScenario lightTaskScenario() {
  const seed = 's0';
  final nodes = <GraphNode>[
    GraphNode(
      id: seed,
      type: GraphNodeType.task,
      label: 'Morning run',
      categoryId: catHealth,
      createdAt: _daysAgo(1),
    ),
    GraphNode(
      id: 'sp',
      type: GraphNodeType.project,
      label: 'Marathon prep',
      categoryId: catHealth,
      createdAt: _daysAgo(90),
    ),
    GraphNode(
      id: 'sl1',
      type: GraphNodeType.audioEntry,
      label: 'Felt strong today',
      categoryId: catHealth,
      createdAt: _daysAgo(1),
    ),
    GraphNode(
      id: 'sl2',
      type: GraphNodeType.textEntry,
      label: '8km easy',
      categoryId: catHealth,
      createdAt: _daysAgo(1),
    ),
    GraphNode(
      id: 'st1',
      type: GraphNodeType.task,
      label: 'Buy new shoes',
      categoryId: catHome,
      createdAt: _daysAgo(4),
    ),
  ];
  final edges = <GraphEdge>[
    const GraphEdge(fromId: 'sp', toId: seed, kind: GraphEdgeKind.containment),
    const GraphEdge(fromId: seed, toId: 'sl1', kind: GraphEdgeKind.association),
    const GraphEdge(fromId: seed, toId: 'sl2', kind: GraphEdgeKind.association),
    const GraphEdge(fromId: seed, toId: 'st1', kind: GraphEdgeKind.association),
  ];
  return GraphScenario(
    name: 'Light task',
    seedId: seed,
    nodes: nodes,
    edges: edges,
    now: _now,
  );
}

/// A large, connected "world" to actually explore: several projects, each with
/// tasks (cross-linked between projects so there are paths to walk), and each
/// task carrying log entries, occasional AI summaries, ratings and checklists.
/// ~120 nodes — big enough that you only ever see a local neighborhood and
/// traverse to discover the rest. Deterministic (index-driven, no RNG).
GraphScenario exploreWorldScenario() {
  final nodes = <GraphNode>[];
  final edges = <GraphEdge>[];
  const projCats = [catWork, catHealth, catWriting, catLearning, catHome];
  const projNames = [
    'Lotti 2.x',
    'Marathon prep',
    'Novel draft',
    'Spanish',
    'Home reno',
  ];
  const logTypes = [
    GraphNodeType.textEntry,
    GraphNodeType.audioEntry,
    GraphNodeType.imageEntry,
  ];
  const taskNames = ['scope', 'build', 'review', 'polish', 'ship'];
  final firstTask = <String>[];
  final lastTask = <String>[];

  for (var p = 0; p < projNames.length; p++) {
    final pid = 'P$p';
    final cat = projCats[p];
    nodes.add(
      GraphNode(
        id: pid,
        type: GraphNodeType.project,
        label: projNames[p],
        categoryId: cat,
        createdAt: _daysAgo(80.0 + p * 12),
      ),
    );
    for (var t = 0; t < taskNames.length; t++) {
      final tid = 'P${p}T$t';
      nodes.add(
        GraphNode(
          id: tid,
          type: GraphNodeType.task,
          label: '${projNames[p]} · ${taskNames[t]}',
          categoryId: cat,
          createdAt: _daysAgo(3.0 + p * 4 + t),
        ),
      );
      edges.add(
        GraphEdge(fromId: pid, toId: tid, kind: GraphEdgeKind.containment),
      );
      if (t == 0) firstTask.add(tid);
      if (t == taskNames.length - 1) lastTask.add(tid);

      final logN = 1 + ((p + t) % 3);
      for (var l = 0; l < logN; l++) {
        final lid = '${tid}L$l';
        nodes.add(
          GraphNode(
            id: lid,
            type: logTypes[(t + l) % 3],
            label: '${taskNames[t]} note ${l + 1}',
            categoryId: cat,
            createdAt: _daysAgo(1.0 + l * 2 + t),
          ),
        );
        edges.add(
          GraphEdge(fromId: tid, toId: lid, kind: GraphEdgeKind.association),
        );
      }
      if ((p + t) % 3 == 0) {
        final aid = '${tid}A';
        nodes.add(
          GraphNode(
            id: aid,
            type: GraphNodeType.aiResponse,
            label: 'AI summary',
            categoryId: cat,
            createdAt: _daysAgo(2.0 + t),
          ),
        );
        edges.add(
          GraphEdge(fromId: aid, toId: tid, kind: GraphEdgeKind.provenance),
        );
      }
      if ((p + t) % 4 == 1) {
        final rid = '${tid}R';
        nodes.add(
          GraphNode(
            id: rid,
            type: GraphNodeType.rating,
            label: 'rated',
            categoryId: cat,
            createdAt: _daysAgo(1.0 + t),
          ),
        );
        edges.add(
          GraphEdge(fromId: rid, toId: tid, kind: GraphEdgeKind.evaluation),
        );
      }
      if (t == 1) {
        final cid = '${tid}C';
        nodes.add(
          GraphNode(
            id: cid,
            type: GraphNodeType.checklist,
            label: 'checklist',
            categoryId: cat,
            createdAt: _daysAgo(5.0 + t),
          ),
        );
        edges.add(
          GraphEdge(fromId: tid, toId: cid, kind: GraphEdgeKind.association),
        );
        for (var c = 0; c < 4; c++) {
          final ciid = '${cid}I$c';
          nodes.add(
            GraphNode(
              id: ciid,
              type: GraphNodeType.checklistItem,
              label: 'item ${c + 1}',
              categoryId: cat,
              createdAt: _daysAgo(2.0 + c),
            ),
          );
          edges.add(
            GraphEdge(fromId: cid, toId: ciid, kind: GraphEdgeKind.checklist),
          );
        }
      }
    }
  }

  // Cross-project task links — the paths that let you walk between clusters.
  for (var p = 0; p < projNames.length; p++) {
    final next = (p + 1) % projNames.length;
    edges.add(
      GraphEdge(
        fromId: lastTask[p],
        toId: firstTask[next],
        kind: GraphEdgeKind.association,
      ),
    );
  }
  edges
    ..add(
      const GraphEdge(
        fromId: 'P0T2',
        toId: 'P2T1',
        kind: GraphEdgeKind.association,
      ),
    )
    ..add(
      const GraphEdge(
        fromId: 'P1T3',
        toId: 'P3T0',
        kind: GraphEdgeKind.association,
      ),
    );

  return GraphScenario(
    name: 'Explore world',
    seedId: 'P0T0',
    nodes: nodes,
    edges: edges,
    now: _now,
  );
}

/// All task-view scenarios, headline first.
List<GraphScenario> allTaskScenarios() => [
  taskEgoNetworkScenario(),
  busyTaskScenario(),
  lightTaskScenario(),
];

/// Scenarios for the interactive dev harness — the explorable world first.
List<GraphScenario> allScenarios() => [
  exploreWorldScenario(),
  ...allTaskScenarios(),
];
