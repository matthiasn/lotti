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

    // A required label that found no clean anchor degrades gracefully: take
    // the least-overlapping anchor that still clears the viewport AND the
    // reserved chrome, rather than being dropped (which leaves the node
    // anonymous) or hard-clamped onto the chrome (which is what put callout
    // fragments under the toolbar).
    choice ??= candidate.required
        ? _bestEffortPlacement(
            candidate: candidate,
            anchors: anchors,
            viewport: viewport,
            nodeObstacles: nodeObstacles,
            reservedRects: reservedRects,
            placed: placed,
            gap: gap,
          )
        : null;

    if (choice != null) placed[candidate.id] = choice;
  }
  return placed;
}

/// Least-bad placement for a [candidate] whose anchors all collide.
///
/// Scores every anchor by the area it would overlap (node bodies weigh more
/// than other labels, since covering a node hides the thing being named) and
/// keeps the cheapest one. Anchors that leave the viewport or touch reserved
/// chrome are never eligible; when none is, the label is nudged back inside
/// the viewport and away from the reserved rects instead.
GraphLabelPlacement? _bestEffortPlacement({
  required GraphLabelCandidate candidate,
  required List<GraphLabelAnchor> anchors,
  required Rect viewport,
  required Map<String, Rect> nodeObstacles,
  required List<Rect> reservedRects,
  required Map<String, GraphLabelPlacement> placed,
  required double gap,
}) {
  GraphLabelAnchor? bestAnchor;
  Rect? bestRect;
  var bestPenalty = double.infinity;

  for (final anchor in anchors) {
    final rect = _rectFor(candidate, anchor, gap);
    if (!viewport.contains(rect.topLeft) ||
        !viewport.contains(rect.bottomRight) ||
        reservedRects.any(rect.overlaps)) {
      continue;
    }
    var penalty = 0.0;
    for (final entry in nodeObstacles.entries) {
      if (entry.key == candidate.id) continue;
      penalty += _overlapArea(rect, entry.value) * 2;
    }
    for (final item in placed.values) {
      penalty += _overlapArea(rect, item.rect);
    }
    if (penalty < bestPenalty) {
      bestPenalty = penalty;
      bestAnchor = anchor;
      bestRect = rect;
    }
  }

  if (bestAnchor != null && bestRect != null) {
    return GraphLabelPlacement(
      id: candidate.id,
      rect: bestRect,
      anchor: bestAnchor,
      nodeCenter: candidate.center,
    );
  }

  // Nothing fits cleanly: clamp into the viewport, then push clear of any
  // reserved rect it still lands on.
  final anchor = anchors.first;
  final raw = _rectFor(candidate, anchor, gap);
  final maxLeft = viewport.right - raw.width;
  final maxTop = viewport.bottom - raw.height;
  var rect = Rect.fromLTWH(
    maxLeft <= viewport.left
        ? viewport.left
        : raw.left.clamp(viewport.left, maxLeft),
    maxTop <= viewport.top ? viewport.top : raw.top.clamp(viewport.top, maxTop),
    raw.width,
    raw.height,
  );
  rect = _pushOutOfReserved(rect, reservedRects, viewport);
  return GraphLabelPlacement(
    id: candidate.id,
    rect: rect,
    anchor: anchor,
    nodeCenter: candidate.center,
  );
}

/// Slides [rect] off any reserved rect it overlaps, along whichever axis costs
/// the least travel, keeping it inside [viewport]. Returns the original rect
/// when no escape keeps it in the viewport (a viewport smaller than its own
/// chrome), so the label still renders rather than vanishing.
Rect _pushOutOfReserved(Rect rect, List<Rect> reserved, Rect viewport) {
  var current = rect;
  for (var pass = 0; pass < reserved.length + 1; pass++) {
    Rect? hit;
    for (final candidate in reserved) {
      if (current.overlaps(candidate)) {
        hit = candidate;
        break;
      }
    }
    if (hit == null) return current;
    final candidates =
        <Rect>[
          current.translate(hit.left - current.right, 0),
          current.translate(hit.right - current.left, 0),
          current.translate(0, hit.top - current.bottom),
          current.translate(0, hit.bottom - current.top),
        ].where(
          (option) =>
              viewport.contains(option.topLeft) &&
              viewport.contains(option.bottomRight),
        );
    if (candidates.isEmpty) return rect;
    var best = candidates.first;
    var bestTravel = double.infinity;
    for (final option in candidates) {
      final travel = (option.center - rect.center).distance;
      if (travel < bestTravel) {
        bestTravel = travel;
        best = option;
      }
    }
    current = best;
  }
  return current;
}

double _overlapArea(Rect a, Rect b) {
  final intersection = a.intersect(b);
  if (intersection.isEmpty) return 0;
  return intersection.width * intersection.height;
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
