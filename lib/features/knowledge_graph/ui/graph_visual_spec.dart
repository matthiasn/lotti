import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/knowledge_graph/ui/graph_style.dart';

/// User-selectable information density for the local graph.
enum GraphDensity { calm, balanced, explore }

/// The graph's named visual and algorithmic contract.
///
/// Palette and typography remain owned by the app design system through
/// [style]. Values here are graph-only geometry and readability thresholds;
/// keeping them together prevents painter, layout, and overlays from drifting.
@immutable
class GraphVisualSpec {
  const GraphVisualSpec({
    required this.style,
    this.calmNodeLimit = defaultCalmNodeLimit,
    this.balancedNodeLimit = defaultBalancedNodeLimit,
    this.exploreNodeLimit = defaultExploreNodeLimit,
    this.clusterPreviewLimit = defaultClusterPreviewLimit,
    this.clusterCollapseThreshold = defaultClusterCollapseThreshold,
    this.focusLabelMaxWidth = 280,
    this.nodeLabelMaxWidth = 210,
    this.labelGap = 6,
    this.labelHorizontalPadding = 8,
    this.labelVerticalPadding = 5,
    this.minimapWidth = 216,
    this.minimapHeight = 144,
    this.legendMaxWidth = 260,
    this.minimapNodeRadius = 2.4,
    this.minimapFocusRadius = 4.5,
    this.minimapEdgeAlpha = 0.28,
    this.minimapNodeAlpha = 0.72,
  });

  factory GraphVisualSpec.fromTokens(
    DsTokens tokens, {
    Map<String, Color>? categoryColors,
    bool highContrast = false,
  }) => GraphVisualSpec(
    style: GraphStyle.fromTokens(
      tokens,
      categoryColors: categoryColors,
      highContrast: highContrast,
    ),
  );

  static const int defaultCalmNodeLimit = 24;
  static const int defaultBalancedNodeLimit = 48;
  static const int defaultExploreNodeLimit = 72;
  static const int defaultClusterPreviewLimit = 5;
  static const int defaultClusterCollapseThreshold = 8;

  final GraphStyle style;
  final int calmNodeLimit;
  final int balancedNodeLimit;
  final int exploreNodeLimit;
  final int clusterPreviewLimit;
  final int clusterCollapseThreshold;
  final double focusLabelMaxWidth;
  final double nodeLabelMaxWidth;
  final double labelGap;
  final double labelHorizontalPadding;
  final double labelVerticalPadding;
  final double minimapWidth;
  final double minimapHeight;
  final double legendMaxWidth;
  final double minimapNodeRadius;
  final double minimapFocusRadius;
  final double minimapEdgeAlpha;
  final double minimapNodeAlpha;

  int nodeLimit(GraphDensity density) => switch (density) {
    GraphDensity.calm => calmNodeLimit,
    GraphDensity.balanced => balancedNodeLimit,
    GraphDensity.explore => exploreNodeLimit,
  };
}
