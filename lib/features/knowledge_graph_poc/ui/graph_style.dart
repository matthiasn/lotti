/// Token-backed visual styling for the knowledge-graph POC.
///
/// All colors and text styles come from the design system (`DsTokens`); the
/// painter receives a plain value object so it never needs a `BuildContext`.
/// Category → color, node-type → glyph, and relation-class → edge style follow
/// ADR 0029 Decision 3/4. The generic `BasicLink` "association" is split by its
/// target into a linked-task tie vs a note/log tie (the explicit-semantic idea
/// from the ontology brief).
library;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_scenarios.dart';

/// Material glyph for each node type (ADR 0029 Decision 4 — existing
/// iconography reads better than 16 abstract shapes).
IconData glyphForType(GraphNodeType type) {
  switch (type) {
    case GraphNodeType.task:
      return Icons.check_circle_outline;
    case GraphNodeType.project:
      return Icons.flag_outlined;
    case GraphNodeType.textEntry:
      return Icons.notes;
    case GraphNodeType.audioEntry:
      return Icons.mic_none;
    case GraphNodeType.imageEntry:
      return Icons.image_outlined;
    case GraphNodeType.aiResponse:
      return Icons.auto_awesome;
    case GraphNodeType.checklist:
      return Icons.checklist;
    case GraphNodeType.checklistItem:
      return Icons.check_box_outlined;
    case GraphNodeType.rating:
      return Icons.star_outline;
  }
}

/// Human-readable node-type label for the inspector.
String typeLabel(GraphNodeType type) {
  switch (type) {
    case GraphNodeType.task:
      return 'Task';
    case GraphNodeType.project:
      return 'Project';
    case GraphNodeType.textEntry:
      return 'Note';
    case GraphNodeType.audioEntry:
      return 'Audio note';
    case GraphNodeType.imageEntry:
      return 'Photo';
    case GraphNodeType.aiResponse:
      return 'AI summary';
    case GraphNodeType.checklist:
      return 'Checklist';
    case GraphNodeType.checklistItem:
      return 'Checklist item';
    case GraphNodeType.rating:
      return 'Rating';
  }
}

/// A visually distinct relation style. Coarser than [GraphEdgeKind] in one
/// place (kinds map straight through) but finer in another: the generic
/// association splits into [linkedTask] vs [note].
enum RelStyle {
  containment,
  linkedTask,
  note,
  checklist,
  provenance,
  evaluation,
}

/// Map an edge to its visual relation style, using the *target* node type to
/// disambiguate the generic association.
RelStyle relStyleFor(GraphEdgeKind kind, GraphNodeType targetType) {
  switch (kind) {
    case GraphEdgeKind.containment:
      return RelStyle.containment;
    case GraphEdgeKind.provenance:
      return RelStyle.provenance;
    case GraphEdgeKind.evaluation:
      return RelStyle.evaluation;
    case GraphEdgeKind.checklist:
      return RelStyle.checklist;
    case GraphEdgeKind.association:
      return targetType == GraphNodeType.task
          ? RelStyle.linkedTask
          : RelStyle.note;
  }
}

String relStyleLabel(RelStyle style) {
  switch (style) {
    case RelStyle.containment:
      return 'in project';
    case RelStyle.linkedTask:
      return 'linked task';
    case RelStyle.note:
      return 'note / log';
    case RelStyle.checklist:
      return 'checklist';
    case RelStyle.provenance:
      return 'AI source';
    case RelStyle.evaluation:
      return 'rating';
  }
}

/// The relation styles actually present in a scenario, in enum order.
List<RelStyle> relStylesIn(GraphScenario scenario) {
  final nodeType = {for (final n in scenario.nodes) n.id: n.type};
  final present = <RelStyle>{};
  for (final e in scenario.edges) {
    final tt = nodeType[e.toId];
    if (tt != null) present.add(relStyleFor(e.kind, tt));
  }
  final ordered = present.toList()..sort((a, b) => a.index.compareTo(b.index));
  return ordered;
}

/// Stroke styling for one relation class.
@immutable
class EdgeVisual {
  const EdgeVisual({
    required this.color,
    required this.width,
    this.dash,
    this.directional = false,
  });

  final Color color;
  final double width;

  /// `[dashLength, gapLength]`, or null for a solid line.
  final List<double>? dash;
  final bool directional;
}

/// Immutable bundle of resolved colors/styles, built once per frame from theme
/// tokens.
@immutable
class GraphStyle {
  const GraphStyle({
    required this.background,
    required this.backgroundDeep,
    required this.vignetteLift,
    required this.starColor,
    required this.focusRing,
    required this.selectionRing,
    required this.fadeTarget,
    required this.coreLift,
    required this.glyphColor,
    required this.labelStyle,
    required this.legendStyle,
    required this.titleStyle,
    required this.labelPill,
    required this.categoryPalette,
    required this.relVisuals,
  });

  factory GraphStyle.fromTokens(DsTokens t) {
    return GraphStyle(
      background: t.colors.background.level01,
      backgroundDeep: t.colors.background.alternative01,
      vignetteLift: t.colors.background.level03,
      starColor: t.colors.text.lowEmphasis,
      focusRing: t.colors.interactive.enabled,
      selectionRing: t.colors.interactive.hover,
      fadeTarget: t.colors.background.level01,
      coreLift: t.colors.text.onInteractiveAlert,
      glyphColor: t.colors.text.onInteractiveAlert,
      labelStyle: t.typography.styles.others.caption.copyWith(
        color: t.colors.text.highEmphasis,
      ),
      legendStyle: t.typography.styles.others.overline.copyWith(
        color: t.colors.text.mediumEmphasis,
      ),
      titleStyle: t.typography.styles.subtitle.subtitle1.copyWith(
        color: t.colors.text.highEmphasis,
      ),
      labelPill: t.colors.background.level02,
      categoryPalette: <String, Color>{
        catWork: t.colors.aiProvider.gemini.color,
        catWriting: t.colors.aiProvider.openAi.color,
        catHealth: t.colors.aiProvider.anthropic.color,
        catLearning: t.colors.aiProvider.ollama.color,
        catHome: t.colors.aiProvider.alibaba.color,
        catAdmin: t.colors.proposalKind.add.color,
      },
      relVisuals: <RelStyle, EdgeVisual>{
        // Containment is the structural backbone: thickest, most opaque.
        RelStyle.containment: EdgeVisual(
          color: t.colors.text.highEmphasis,
          width: 2.8,
          directional: true,
        ),
        RelStyle.linkedTask: EdgeVisual(
          color: t.colors.text.mediumEmphasis,
          width: 1.8,
          dash: const [7, 5],
          directional: true,
        ),
        RelStyle.note: EdgeVisual(
          color: t.colors.text.mediumEmphasis,
          width: 1.4,
        ),
        RelStyle.checklist: EdgeVisual(
          color: t.colors.text.lowEmphasis,
          width: 1.5,
        ),
        // AI-source uses the info cyan, rating uses the remove pink — both are
        // OUTSIDE the category palette (teal/terracotta/indigo/purple/orange/
        // green) so an edge hue is never confused with a node category.
        RelStyle.provenance: EdgeVisual(
          color: t.colors.alert.info.defaultColor,
          width: 1.9,
          dash: const [7, 5],
          directional: true,
        ),
        RelStyle.evaluation: EdgeVisual(
          color: t.colors.proposalKind.remove.color,
          width: 1.9,
          dash: const [3, 4],
          directional: true,
        ),
      },
    );
  }

  final Color background;
  final Color backgroundDeep;
  final Color vignetteLift;
  final Color starColor;
  final Color focusRing;
  final Color selectionRing;
  final Color fadeTarget;
  final Color coreLift;
  final Color glyphColor;
  final TextStyle labelStyle;
  final TextStyle legendStyle;
  final TextStyle titleStyle;
  final Color labelPill;
  final Map<String, Color> categoryPalette;
  final Map<RelStyle, EdgeVisual> relVisuals;

  Color categoryColor(String categoryId) {
    final direct = categoryPalette[categoryId];
    if (direct != null) return direct;
    final values = categoryPalette.values.toList();
    return values[categoryId.hashCode.abs() % values.length];
  }

  EdgeVisual edgeVisual(RelStyle style) => relVisuals[style]!;
}
