import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

/// One building in the plaza: geometry handles plus everything the facade
/// LOD manager needs to promote/demote its surface.
class PlazaBuilding {
  PlazaBuilding({
    required this.task,
    required this.placement,
    required this.node,
    required this.facadeAnchor,
    required this.facadeCenter,
    required this.facadeWorldWidth,
    required this.facadeWorldHeight,
    required this.pxPerMeter,
  });

  final PlazaTask task;
  final PlotPlacement placement;

  /// The building root (box mesh), attached to the scene.
  final Node node;

  /// Child node on the street-facing wall; the LOD manager attaches
  /// [WidgetComponent]s here.
  final Node facadeAnchor;

  /// World-space center of the facade, for camera-distance ranking.
  final Vector3 facadeCenter;

  final double facadeWorldWidth;
  final double facadeWorldHeight;

  /// Pixels per world meter for this building's facade texture, from the
  /// layout that placed it (the content-height estimate uses the same).
  final double pxPerMeter;

  /// Logical layout size for the facade widget subtree.
  Size get widgetSize => Size(
    facadeWorldWidth * pxPerMeter,
    facadeWorldHeight * pxPerMeter,
  );
}

/// Builds and owns the plaza [Scene]: ground, road, buildings, dusk light.
///
/// Registration is deliberately register-neutral and unlit (spec §8): the
/// scene defaults to dusk so luminance contrast — the attention mechanism —
/// has somewhere to live, and M0 measures widget-surface cost, not PBR cost.
class PlazaSceneController {
  PlazaSceneController({
    required List<PlazaTask> tasks,
    required int projectSeed,
    StreetLayout? layout,
  }) : layout = layout ?? StreetLayout(projectSeed: projectSeed) {
    plan = this.layout.plan(tasks);
    _build(tasks);
  }

  final StreetLayout layout;
  late final StreetPlan plan;
  final Scene scene = Scene();
  final List<PlazaBuilding> buildings = [];

  /// Where the plaza opens without a specific task: at the frontier (the
  /// newest buildings), looking back down the street (spec §10).
  late final Vector3 frontierEye;
  late final double frontierYaw;

  static Vector4 _rgba(int argb, {double alpha = 1, double dim = 1}) {
    return Vector4(
      ((argb >> 16) & 0xFF) / 255 * dim,
      ((argb >> 8) & 0xFF) / 255 * dim,
      (argb & 0xFF) / 255 * dim,
      alpha,
    );
  }

  void _build(List<PlazaTask> tasks) {
    final byId = {for (final t in tasks) t.id: t};

    // Ground: one big dark slab under everything.
    final groundCenter = _planCenter();
    scene.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(groundCenter.x, -0.06, groundCenter.z),
        ),
        mesh: Mesh(
          CuboidGeometry(Vector3(4000, 0.1, 4000)),
          UnlitMaterial()..baseColorFactor = Vector4(0.045, 0.05, 0.065, 1),
        ),
      ),
    );

    // Road: one slab per segment; collapsed gap weeks read darker.
    for (final segment in plan.segments) {
      final midAlong = segment.length / 2;
      final mid = Vector3(
        segment.startX + math.sin(segment.headingRadians) * midAlong,
        0,
        segment.startZ + math.cos(segment.headingRadians) * midAlong,
      );
      final shade = segment.isGap ? 0.06 : 0.09;
      scene.add(
        Node(
          localTransform: Matrix4.translation(mid)
            ..rotateY(segment.headingRadians),
          mesh: Mesh(
            CuboidGeometry(
              Vector3(layout.roadWidth, 0.08, segment.length + 0.4),
            ),
            UnlitMaterial()
              ..baseColorFactor = Vector4(shade, shade, shade * 1.2, 1),
          ),
        ),
      );
    }

    for (final placement in plan.placements.values) {
      final task = byId[placement.taskId];
      if (task == null) continue;
      if (task.deleted) {
        _buildEmptyLot(placement);
      } else {
        _buildBuilding(task, placement);
      }
    }

    _computeFrontierSpawn();
  }

  void _buildBuilding(PlazaTask task, PlotPlacement placement) {
    final w = placement.width;
    final h = placement.height;
    final d = placement.depth;

    // Walls: dark, faintly tinted by category so blocks read apart at dusk.
    final wall = UnlitMaterial()
      ..baseColorFactor =
          _rgba(task.categoryColor, dim: 0.10) + Vector4(0.05, 0.05, 0.06, 0);

    final node = Node(
      localTransform: Matrix4.translation(
        Vector3(placement.x, h / 2, placement.z),
      )..rotateY(placement.facingRadians),
      mesh: Mesh(CuboidGeometry(Vector3(w, h, d)), wall),
    );

    final facadeW = w * 0.92;
    final facadeH = h * 0.88;

    // Far-tier surface: an always-present color block on the facade —
    // state as color, no text (spec §9 LOD "far").
    final farColor = switch (task.state) {
      PlazaTaskState.done => Vector4(0.10, 0.28, 0.19, 1),
      PlazaTaskState.cancelled => Vector4(0.10, 0.11, 0.13, 1),
      PlazaTaskState.blocked => Vector4(0.36, 0.16, 0.13, 1),
      PlazaTaskState.inProgress => Vector4(0.13, 0.22, 0.40, 1),
      PlazaTaskState.open => Vector4(0.16, 0.17, 0.21, 1),
    };
    node.add(
      Node(
        localTransform: Matrix4.translation(Vector3(0, 0, d / 2 + 0.02)),
        mesh: Mesh(
          CuboidGeometry(Vector3(facadeW, facadeH, 0.02)),
          UnlitMaterial()..baseColorFactor = farColor,
        ),
      ),
    );

    // Anchor for the live/mid widget surface, in front of the color block.
    final facadeAnchor = Node(
      localTransform: Matrix4.translation(Vector3(0, 0, d / 2 + 0.09)),
    );
    node.add(facadeAnchor);

    scene.add(node);

    final facing = placement.facingRadians;
    buildings.add(
      PlazaBuilding(
        task: task,
        placement: placement,
        node: node,
        facadeAnchor: facadeAnchor,
        facadeCenter: Vector3(
          placement.x + math.sin(facing) * (d / 2),
          h / 2,
          placement.z + math.cos(facing) * (d / 2),
        ),
        facadeWorldWidth: facadeW,
        facadeWorldHeight: facadeH,
        pxPerMeter: layout.pxPerMeter,
      ),
    );
  }

  void _buildEmptyLot(PlotPlacement placement) {
    // Fenced empty lot: foundations visible, street never closes up.
    scene.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(placement.x, 0.25, placement.z),
        )..rotateY(placement.facingRadians),
        mesh: Mesh(
          CuboidGeometry(Vector3(placement.width, 0.5, placement.depth)),
          UnlitMaterial()..baseColorFactor = Vector4(0.07, 0.07, 0.08, 1),
        ),
      ),
    );
  }

  Vector3 _planCenter() {
    if (plan.segments.isEmpty) return Vector3.zero();
    var sumX = 0.0;
    var sumZ = 0.0;
    for (final s in plan.segments) {
      sumX += s.startX;
      sumZ += s.startZ;
    }
    return Vector3(sumX / plan.segments.length, 0, sumZ / plan.segments.length);
  }

  void _computeFrontierSpawn() {
    if (plan.segments.isEmpty) {
      frontierEye = Vector3(0, 1.7, -6);
      frontierYaw = 0;
      return;
    }
    final last = plan.segments.last;
    final endAlong = last.length;
    frontierEye = Vector3(
      last.startX + math.sin(last.headingRadians) * endAlong,
      1.7,
      last.startZ + math.cos(last.headingRadians) * endAlong,
    );
    // Look back down the street: history one turn away, not in the way.
    frontierYaw = last.headingRadians + math.pi;
  }
}
