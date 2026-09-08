import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/street_layout.dart';

/// Related silhouettes for the nighttime district. Status never selects a kit.
enum BuildingFamily { steppedTower, mediaTower, theater }

/// World-space proportions, independent of widget pixels and theme spacing.
/// Keeping these inputs separate lets generation vary architecture without
/// changing a task's timeline address or its approach path.
class ArchitectureConfig {
  const ArchitectureConfig({
    this.seed = 0,
    this.streetwallFraction = 0.72,
    this.towerInsetFraction = 0.16,
  }) : assert(
         streetwallFraction >= 0.6 && streetwallFraction <= 0.8,
         'street wall must reserve a crown',
       ),
       assert(
         towerInsetFraction >= 0.1 && towerInsetFraction <= 0.25,
         'crown must remain inside the plot',
       );

  final int seed;
  final double streetwallFraction;
  final double towerInsetFraction;
}

/// A solid architectural volume, in a building's ground-centred local frame.
/// +Z faces the street. Every volume stays inside the reserved plot envelope.
class BuildingVolume {
  const BuildingVolume({
    required this.width,
    required this.depth,
    required this.bottom,
    required this.height,
    this.x = 0,
    this.z = 0,
  });

  final double width;
  final double depth;
  final double bottom;
  final double height;
  final double x;
  final double z;

  double get top => bottom + height;
}

/// Shared CPU recipe for geometry and facade bindings. The facade's original
/// street plane is retained while smaller upper volumes expose the silhouette.
class BuildingArchitecture {
  BuildingArchitecture._({
    required this.family,
    required this.volumes,
    required this.front,
    required this.frontageHeight,
    required this.entranceHeight,
    required this.facadeWidth,
    required this.facadeHeight,
    required this.facadeBottom,
  });

  factory BuildingArchitecture.forPlot(
    PlotPlacement plot, {
    ArchitectureConfig config = const ArchitectureConfig(),
    double billboardScale = 1,
  }) => BuildingArchitecture.forEnvelope(
    id: plot.taskId,
    width: plot.width,
    depth: plot.depth,
    height: plot.height,
    config: config,
    billboardScale: billboardScale,
  );

  factory BuildingArchitecture.forEnvelope({
    required String id,
    required double width,
    required double depth,
    required double height,
    ArchitectureConfig config = const ArchitectureConfig(),
    BuildingFamily? family,
    double billboardScale = 1,
    double minimumFrontageHeight = 0,
  }) {
    assert(
      width > 0 && depth > 0 && height > 0,
      'positive building dimensions required',
    );
    assert(
      billboardScale > 0 && billboardScale <= 1,
      'sign must fit its frontage',
    );
    assert(
      minimumFrontageHeight >= 0 && minimumFrontageHeight <= height,
      'frontage must fit the building',
    );
    final kit =
        family ??
        BuildingFamily.values[stableIndex(
          '$id:${config.seed}',
          'architecture-v1',
          BuildingFamily.values.length,
        )];
    final streetwall = math.max(
      height * config.streetwallFraction,
      minimumFrontageHeight,
    );
    final crownHeight = height - streetwall;
    final inset = config.towerInsetFraction;
    // Recess the ground floor behind the sign plane; its canopy can then
    // occupy the original plot rather than protruding into the walking lane.
    final entrance = math.min<double>(4, streetwall * 0.3);
    final recess = math.min(depth * 0.08, entrance * 0.2);
    final volumes = <BuildingVolume>[
      BuildingVolume(
        width: width,
        depth: depth - recess,
        bottom: 0,
        height: entrance,
        z: -recess / 2,
      ),
      BuildingVolume(
        width: width,
        depth: depth,
        bottom: entrance,
        height: streetwall - entrance,
      ),
    ];
    if (crownHeight > 0) {
      switch (kit) {
        case BuildingFamily.steppedTower:
          volumes.addAll([
            BuildingVolume(
              width: width * (1 - inset),
              depth: depth * (1 - inset),
              bottom: streetwall,
              height: crownHeight * 0.6,
              z: -depth * inset / 2,
            ),
            BuildingVolume(
              width: width * (1 - inset * 2),
              depth: depth * (1 - inset * 2),
              bottom: streetwall + crownHeight * 0.6,
              height: crownHeight * 0.4,
              z: -depth * inset,
            ),
          ]);
        case BuildingFamily.mediaTower:
          // An offset narrow crown leaves a broad corner terrace.
          volumes.add(
            BuildingVolume(
              width: width * (1 - inset * 2),
              depth: depth * (1 - inset),
              bottom: streetwall,
              height: crownHeight,
              x: width * inset,
              z: -depth * inset / 2,
            ),
          );
        case BuildingFamily.theater:
          volumes.add(
            BuildingVolume(
              width: width * (1 - inset),
              depth: depth * (1 - inset * 2),
              bottom: streetwall,
              height: crownHeight,
              z: -depth * inset,
            ),
          );
      }
    }
    final frame = math.min(width, streetwall) * 0.05;
    final panelHeight = streetwall - entrance - frame * 2;
    return BuildingArchitecture._(
      family: kit,
      volumes: List.unmodifiable(volumes),
      front: depth / 2,
      frontageHeight: streetwall,
      entranceHeight: entrance,
      facadeWidth: width * (1 - inset) * billboardScale,
      facadeHeight: panelHeight * billboardScale,
      facadeBottom: entrance + frame + panelHeight * (1 - billboardScale) / 2,
    );
  }

  final BuildingFamily family;
  final List<BuildingVolume> volumes;
  final double front;
  final double frontageHeight;
  final double entranceHeight;
  final double facadeWidth;
  final double facadeHeight;
  final double facadeBottom;

  double get facadeCenterY => facadeBottom + facadeHeight / 2;
}
