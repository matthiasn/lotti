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

  /// A task-local collection of photos. Individual image nodes stay hidden
  /// until the collection is explicitly expanded.
  mediaCollection,

  /// A collapsed, exact-count group of otherwise visible neighbours.
  aggregate,
}

/// Task state projected into the graph without coupling the painter to the
/// generated journal model.
enum GraphTaskStatus {
  open,
  inProgress,
  groomed,
  blocked,
  onHold,
  done,
  rejected,
}

/// Why a display node represents more than one raw graph node.
enum GraphAggregateKind { photos, relation }

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

  /// Task relationship vocabulary from ADR 0042. Direction is preserved:
  /// `fromId` performs the relation toward `toId`.
  blocks,
  followsUp,
  duplicates,
  fixes,
  supersedes,
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
    this.coverImagePath,
    this.coverImageCropX = 0.5,
    this.oneLiner,
    this.tldr,
    this.taskStatus,
    this.aggregateKind,
    this.aggregateEdgeKind,
    this.aggregateCount = 0,
    this.memberIds = const [],
    this.mediaPaths = const [],
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

  /// Absolute file path of a task's cover art (its `coverArtId` image), shown
  /// as the inspector cover banner for task nodes. Null when the task has no
  /// cover art or the node is not a task.
  final String? coverImagePath;

  /// Horizontal focal point for task cover art (`0` = left, `1` = right).
  final double coverImageCropX;

  /// Compact one-line tagline for the inspector — a task's assigned-agent
  /// `oneLiner`. Null when the node has no agent one-liner.
  final String? oneLiner;

  /// Summary text for the inspector preview — a task's latest assigned-agent
  /// TL;DR (or full report), or an AI-response node's own text. Null when there
  /// is no summary to show.
  final String? tldr;

  final GraphTaskStatus? taskStatus;

  final GraphAggregateKind? aggregateKind;
  final GraphEdgeKind? aggregateEdgeKind;
  final int aggregateCount;
  final List<String> memberIds;

  /// Preview paths for a media aggregate's mosaic, in display order.
  final List<String> mediaPaths;

  bool get isAggregate => aggregateKind != null;
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
