import 'dart:ui';

enum GraphLabelAnchor {
  bottom,
  top,
  right,
  left,
  bottomRight,
  bottomLeft,
  topRight,
  topLeft,
}

class GraphLabelCandidate {
  const GraphLabelCandidate({
    required this.id,
    required this.center,
    required this.nodeRadius,
    required this.labelSize,
    required this.priority,
    this.required = false,
  });

  final String id;
  final Offset center;
  final double nodeRadius;
  final Size labelSize;
  final int priority;
  final bool required;
}

class GraphLabelPlacement {
  const GraphLabelPlacement({
    required this.id,
    required this.rect,
    required this.anchor,
    required this.nodeCenter,
  });

  final String id;
  final Rect rect;
  final GraphLabelAnchor anchor;
  final Offset nodeCenter;

  bool get needsLeader =>
      (rect.center - nodeCenter).distance > rect.shortestSide;
}

/// Session memory that keeps accepted anchors stable across nearby repaints.
class GraphLabelLayoutMemory {
  Map<String, GraphLabelPlacement> _placements = const {};

  Map<String, GraphLabelPlacement> get placements => _placements;

  void remember(Map<String, GraphLabelPlacement> placements) {
    _placements = Map.unmodifiable(placements);
  }

  void clear() => _placements = const {};
}

/// Deterministic eight-position label solver.
///
/// Higher-priority labels claim space first. Candidate rectangles must stay in
/// [viewport] and avoid reserved overlays, node bodies, and already placed
/// labels. [previous] makes accepted anchors sticky between nearby frames.
Map<String, GraphLabelPlacement> solveGraphLabelLayout({
  required List<GraphLabelCandidate> candidates,
  required Rect viewport,
  required Map<String, Rect> nodeObstacles,
  List<Rect> reservedRects = const [],
  Map<String, GraphLabelPlacement> previous = const {},
  double gap = 6,
}) {
  final ordered = [...candidates]
    ..sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      return priority != 0 ? priority : a.id.compareTo(b.id);
    });
  final placed = <String, GraphLabelPlacement>{};

  for (final candidate in ordered) {
    final anchors = [...GraphLabelAnchor.values];
    final previousAnchor = previous[candidate.id]?.anchor;
    if (previousAnchor != null) {
      anchors
        ..remove(previousAnchor)
        ..insert(0, previousAnchor);
    }

    GraphLabelPlacement? choice;
    for (final anchor in anchors) {
      final rect = _rectFor(candidate, anchor, gap);
      if (!viewport.contains(rect.topLeft) ||
          !viewport.contains(rect.bottomRight)) {
        continue;
      }
      if (reservedRects.any(rect.overlaps) ||
          placed.values.any((item) => item.rect.overlaps(rect)) ||
          nodeObstacles.entries.any(
            (entry) => entry.key != candidate.id && entry.value.overlaps(rect),
          )) {
        continue;
      }
      choice = GraphLabelPlacement(
        id: candidate.id,
        rect: rect,
        anchor: anchor,
        nodeCenter: candidate.center,
      );
      break;
    }

    if (choice == null && candidate.required) {
      final anchor = previousAnchor ?? GraphLabelAnchor.bottom;
      final raw = _rectFor(candidate, anchor, gap);
      final maxLeft = viewport.right - raw.width;
      final maxTop = viewport.bottom - raw.height;
      final rect = Rect.fromLTWH(
        maxLeft <= viewport.left
            ? viewport.left
            : raw.left.clamp(viewport.left, maxLeft),
        maxTop <= viewport.top
            ? viewport.top
            : raw.top.clamp(viewport.top, maxTop),
        raw.width,
        raw.height,
      );
      choice = GraphLabelPlacement(
        id: candidate.id,
        rect: rect,
        anchor: anchor,
        nodeCenter: candidate.center,
      );
    }

    if (choice != null) placed[candidate.id] = choice;
  }
  return placed;
}

Rect _rectFor(
  GraphLabelCandidate candidate,
  GraphLabelAnchor anchor,
  double gap,
) {
  final center = candidate.center;
  final radius = candidate.nodeRadius + gap;
  final width = candidate.labelSize.width;
  final height = candidate.labelSize.height;
  final diagonal = radius * 0.72;
  final topLeft = switch (anchor) {
    GraphLabelAnchor.bottom => Offset(
      center.dx - width / 2,
      center.dy + radius,
    ),
    GraphLabelAnchor.top => Offset(
      center.dx - width / 2,
      center.dy - radius - height,
    ),
    GraphLabelAnchor.right => Offset(
      center.dx + radius,
      center.dy - height / 2,
    ),
    GraphLabelAnchor.left => Offset(
      center.dx - radius - width,
      center.dy - height / 2,
    ),
    GraphLabelAnchor.bottomRight => Offset(
      center.dx + diagonal,
      center.dy + diagonal,
    ),
    GraphLabelAnchor.bottomLeft => Offset(
      center.dx - diagonal - width,
      center.dy + diagonal,
    ),
    GraphLabelAnchor.topRight => Offset(
      center.dx + diagonal,
      center.dy - diagonal - height,
    ),
    GraphLabelAnchor.topLeft => Offset(
      center.dx - diagonal - width,
      center.dy - diagonal - height,
    ),
  };
  return topLeft & candidate.labelSize;
}
