import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_layout_engine.dart';
import 'package:lotti/features/knowledge_graph/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_visual_spec.dart';

class TopologyMiniMap extends StatelessWidget {
  const TopologyMiniMap({
    required this.scenario,
    required this.layout,
    required this.focusId,
    required this.visibleNodeIds,
    required this.spec,
    required this.semanticsLabel,
    required this.onJump,
    super.key,
  });

  final GraphScenario scenario;
  final GraphLayout layout;
  final String focusId;
  final Set<String> visibleNodeIds;
  final GraphVisualSpec spec;
  final String semanticsLabel;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: ExcludeSemantics(
        child: Container(
          width: spec.minimapWidth,
          height: spec.minimapHeight,
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.m),
            border: Border.all(
              color: tokens.colors.decorative.level01,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final transform = TopologyTransform.fit(
                positions: layout.positions,
                size: size,
                inset: tokens.spacing.step3,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final id = nearestTopologyNode(
                    localPosition: details.localPosition,
                    positions: layout.positions,
                    transform: transform,
                  );
                  if (id != null) onJump(id);
                },
                child: CustomPaint(
                  key: const ValueKey('knowledge-graph-topology-minimap'),
                  painter: TopologyMiniMapPainter(
                    scenario: scenario,
                    positions: layout.positions,
                    focusId: focusId,
                    visibleNodeIds: visibleNodeIds,
                    transform: transform,
                    spec: spec,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class TopologyTransform {
  const TopologyTransform({required this.scale, required this.offset});

  factory TopologyTransform.fit({
    required Map<String, Offset> positions,
    required Size size,
    required double inset,
  }) {
    if (positions.isEmpty) {
      return TopologyTransform(scale: 1, offset: size.center(Offset.zero));
    }
    final bounds = topologyBounds(positions.values);
    final width = math.max(bounds.width, 1);
    final height = math.max(bounds.height, 1);
    final availableWidth = math.max(size.width - inset * 2, 1);
    final availableHeight = math.max(size.height - inset * 2, 1);
    final scale = math.min(availableWidth / width, availableHeight / height);
    final contentCenter = bounds.center;
    return TopologyTransform(
      scale: scale,
      offset: size.center(Offset.zero) - contentCenter * scale,
    );
  }

  final double scale;
  final Offset offset;

  Offset toLocal(Offset world) => world * scale + offset;
}

Rect topologyBounds(Iterable<Offset> positions) {
  final iterator = positions.iterator;
  if (!iterator.moveNext()) return Rect.zero;
  var left = iterator.current.dx;
  var right = iterator.current.dx;
  var top = iterator.current.dy;
  var bottom = iterator.current.dy;
  while (iterator.moveNext()) {
    left = math.min(left, iterator.current.dx);
    right = math.max(right, iterator.current.dx);
    top = math.min(top, iterator.current.dy);
    bottom = math.max(bottom, iterator.current.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

String? nearestTopologyNode({
  required Offset localPosition,
  required Map<String, Offset> positions,
  required TopologyTransform transform,
}) {
  String? nearest;
  var distance = double.infinity;
  for (final entry in positions.entries) {
    final candidate = (transform.toLocal(entry.value) - localPosition).distance;
    if (candidate < distance) {
      distance = candidate;
      nearest = entry.key;
    }
  }
  return nearest;
}

class TopologyMiniMapPainter extends CustomPainter {
  const TopologyMiniMapPainter({
    required this.scenario,
    required this.positions,
    required this.focusId,
    required this.visibleNodeIds,
    required this.transform,
    required this.spec,
  });

  final GraphScenario scenario;
  final Map<String, Offset> positions;
  final String focusId;
  final Set<String> visibleNodeIds;
  final TopologyTransform transform;
  final GraphVisualSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final style = spec.style;
    final edgePaint = Paint()
      ..color = style.starColor.withValues(alpha: spec.minimapEdgeAlpha)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final edge in scenario.edges) {
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from == null || to == null) continue;
      canvas.drawLine(
        transform.toLocal(from),
        transform.toLocal(to),
        edgePaint,
      );
    }

    final visiblePoints = <Offset>[];
    for (final node in scenario.nodes) {
      final world = positions[node.id];
      if (world == null) continue;
      final local = transform.toLocal(world);
      if (visibleNodeIds.contains(node.id)) visiblePoints.add(local);
      final isFocus = node.id == focusId;
      canvas.drawCircle(
        local,
        isFocus ? spec.minimapFocusRadius : spec.minimapNodeRadius,
        Paint()
          ..color =
              (isFocus ? style.focusRing : style.categoryColor(node.categoryId))
                  .withValues(alpha: isFocus ? 1 : spec.minimapNodeAlpha),
      );
    }

    if (visiblePoints.isNotEmpty) {
      final crop = topologyBounds(
        visiblePoints,
      ).inflate(spec.minimapNodeRadius);
      canvas.drawRRect(
        RRect.fromRectAndRadius(crop, const Radius.circular(4)),
        Paint()
          ..color = style.focusRing.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(TopologyMiniMapPainter oldDelegate) =>
      oldDelegate.scenario != scenario ||
      oldDelegate.positions != positions ||
      oldDelegate.focusId != focusId ||
      oldDelegate.visibleNodeIds != visibleNodeIds ||
      oldDelegate.transform != transform ||
      oldDelegate.spec != spec;
}
