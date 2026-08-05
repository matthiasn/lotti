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
    this.mediaNodeScale = defaultMediaNodeScale,
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
  static const double defaultMediaNodeScale = 2;

  /// Decode extent that safely covers the largest media node at 1× scale.
  static const double baseMediaDecodeLogicalExtent = 112;
  static const double defaultMediaDecodeLogicalExtent =
      baseMediaDecodeLogicalExtent * defaultMediaNodeScale;

  static int defaultNodeLimit(GraphDensity density) => switch (density) {
    GraphDensity.calm => defaultCalmNodeLimit,
    GraphDensity.balanced => defaultBalancedNodeLimit,
    GraphDensity.explore => defaultExploreNodeLimit,
  };

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

  /// Diameter scale for nodes whose body displays cover art or photo media.
  final double mediaNodeScale;

  /// Longest thumbnail side needed for media nodes in logical pixels.
  double get mediaDecodeLogicalExtent =>
      baseMediaDecodeLogicalExtent * mediaNodeScale;

  int nodeLimit(GraphDensity density) => switch (density) {
    GraphDensity.calm => calmNodeLimit,
    GraphDensity.balanced => balancedNodeLimit,
    GraphDensity.explore => exploreNodeLimit,
  };
}
