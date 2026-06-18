/// Proof-of-concept data model for the knowledge-graph explorer (ADR 0029).
///
/// These are deliberately decoupled from the production `JournalEntity` /
/// `EntryLink` types: the POC renders synthetic, deterministic scenarios so the
/// expert panel can judge the *visualization*, not the data plumbing. When the
/// feature graduates, the real graph will be projected onto these same shapes.
library;

/// The kind of node — drives the glyph (the panel rule: type → glyph, never
/// 16 distinct shapes). Mirrors the journal-entry variants that show up around
/// a task ego-network.
enum GraphNodeType {
  task,
  project,
  textEntry,
  audioEntry,
  imageEntry,
  aiResponse,
  checklist,
  checklistItem,
  rating,
}

/// The semantic relation an edge expresses. ADR 0029 Decision 3/7: layout and
/// styling follow the relation class, and `BasicLink` gains an explicit
/// semantic instead of being an undifferentiated association.
enum GraphEdgeKind {
  /// Project → Task (ProjectLink) — containment.
  containment,

  /// Generic association (BasicLink) — e.g. a work/log entry on a task, or a
  /// task linked to another task.
  association,

  /// AiResponse → source entry (PROV-O provenance).
  provenance,

  /// Rating → rated entity (RatingLink).
  evaluation,

  /// Checklist ↔ ChecklistItem.
  checklist,
}

/// A node in a scenario graph.
class GraphNode {
  const GraphNode({
    required this.id,
    required this.type,
    required this.label,
    required this.categoryId,
    required this.createdAt,
    this.imagePath,
  });

  final String id;
  final GraphNodeType type;
  final String label;

  /// Synthetic category — drives node color (the panel rule: category → color).
  final String categoryId;

  /// Authoring time — drives recency-as-luminance.
  final DateTime createdAt;

  /// Absolute file path for image entries — rendered as a real thumbnail in the
  /// node and the inspector cover. Null for non-image nodes.
  final String? imagePath;
}

/// A directed, typed edge.
class GraphEdge {
  const GraphEdge({
    required this.fromId,
    required this.toId,
    required this.kind,
  });

  final String fromId;
  final String toId;
  final GraphEdgeKind kind;

  /// These relations point at the thing they describe (project → task, AI →
  /// source, rating → task), so an arrowhead reads as "about".
  bool get isDirectional =>
      kind == GraphEdgeKind.containment ||
      kind == GraphEdgeKind.provenance ||
      kind == GraphEdgeKind.evaluation;
}

/// A self-contained scenario: a focus node (the task being explored) plus its
/// ego-network.
class GraphScenario {
  const GraphScenario({
    required this.name,
    required this.seedId,
    required this.nodes,
    required this.edges,
    required this.now,
  });

  final String name;

  /// The ego center — the task the user opened.
  final String seedId;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  /// Deterministic "now" for recency math (never `DateTime.now()`).
  final DateTime now;

  GraphNode nodeById(String id) => nodes.firstWhere((n) => n.id == id);

  /// Age of a node in days relative to [now], clamped at zero.
  double ageDays(GraphNode node) {
    final d = now.difference(node.createdAt).inHours / 24.0;
    return d < 0 ? 0 : d;
  }
}

/// Undirected degree of every node — hubs render larger.
Map<String, int> degreeMap(List<GraphEdge> edges) {
  final degrees = <String, int>{};
  for (final e in edges) {
    degrees[e.fromId] = (degrees[e.fromId] ?? 0) + 1;
    degrees[e.toId] = (degrees[e.toId] ?? 0) + 1;
  }
  return degrees;
}
