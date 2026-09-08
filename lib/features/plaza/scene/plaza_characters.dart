import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
import 'package:lotti/features/plaza/scene/character_limb.dart';
import 'package:lotti/features/plaza/scene/plaza_primitives.dart';
import 'package:vector_math/vector_math.dart';

/// Skinned companions attached after static mesh baking. Geometry and materials
/// are shared; each clone owns its skeleton. The existing Plaza clock drives
/// contact-aware IK and secondary motion without another ticker or mesh upload.
class PlazaCharacters {
  PlazaCharacters({
    required Node parent,
    required List<CharacterCompanion> population,
    required Node? model,
    Texture2D? shadowTexture,
  }) {
    if (population.isEmpty || model == null) return;
    final shadow = shadowTexture == null
        ? null
        : Mesh(
            ccwQuad(2.5, 2.5),
            UnlitMaterial()
              ..alphaMode = AlphaMode.blend
              ..baseColorTexture = shadowTexture
              ..baseColorFactor = linearColor(
                dsTokensDark.colors.background.level01,
                alpha: SurfaceAlphas.linework,
              ),
          );
    for (final companion in population) {
      final penguin = _Penguin(
        model.clone(),
        companion: companion,
      );
      _penguins.add(penguin);
      root.add(penguin.root);
      if (shadow != null) {
        final node = Node(mesh: shadow, name: 'contact-shadow')
          ..raycastable = false
          // Three millimetres above the surface avoids coplanar depth flicker.
          ..localTransform = (Matrix4.translationValues(0, 0.003, 0)
            ..rotateX(-math.pi / 2));
        penguin.root.add(node);
      }
      penguin.pose(0);
    }
    parent.add(root);
  }

  static const asset = 'assets/plaza/penguin.glb';
  final root = Node(name: 'plaza-characters');
  final List<_Penguin> _penguins = [];
  static const visibleRange = 90.0;
  bool get hasVisibleMotion => _hasVisibleMotion;
  bool _hasVisibleMotion = false;
  double? _lastSeconds;
  double _animationSeconds = 0;
  bool _enabled = true;
  bool _disposed = false;

  /// Hide and pause the existing rigs without rebuilding the city or camera.
  /// Reset the time baseline on both edges so hidden time never catches up.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_disposed || value == _enabled) return;
    _enabled = value;
    root.visible = value;
    _lastSeconds = null;
    _hasVisibleMotion = false;
  }

  /// Loads the original model and applies the existing token palette. The
  /// model is authored in Plaza's +Z-forward coordinates, so retain its own
  /// root rather than the importer's source-coordinate conversion wrapper.
  static Future<Node> loadModel() async {
    final imported = await Node.fromGlbAsset(asset);
    final model = imported.getChildByName('penguin-model')!;
    model.parent?.remove(model);
    styleModel(model);
    return model;
  }

  /// Also usable with CPU-only geometry when verifying skeleton bindings.
  static void styleModel(Node model) {
    final colors = <String, Color>{
      'body': dsTokensDark.colors.background.level02,
      'belly': dsTokensLight.colors.background.level01,
      'eyes': dsTokensLight.colors.background.level01,
      'pupils': dsTokensDark.colors.background.level01,
      'glints': dsTokensLight.colors.background.level01,
      'lids': dsTokensLight.colors.background.level01,
      'beak': dsTokensDark.colors.alert.warning.defaultColor,
      'feet': dsTokensDark.colors.alert.warning.defaultColor,
    };
    for (final entry in colors.entries) {
      final node = model.getChildByName('${entry.key}-surface')!
        ..raycastable = false;
      for (final primitive in node.mesh!.primitives) {
        (primitive.material as PhysicallyBasedMaterial).baseColorFactor =
            linearColor(entry.value);
      }
    }
  }

  /// Freezes travel and every joint for reduced motion, with no catch-up jump.
  /// Distant rigs stop rendering and leave the animation frame-rate budget.
  void update({
    required double seconds,
    required Vector3 eye,
    required bool animate,
    bool visible = true,
    double Function(String id)? clockFor,
  }) {
    if (!_enabled || _disposed) return;
    final last = _lastSeconds;
    _lastSeconds = seconds;
    if (animate && last != null) {
      _animationSeconds += math.max(0, seconds - last);
    }
    _hasVisibleMotion = false;
    for (final penguin in _penguins) {
      final time = clockFor?.call(penguin.companion.id) ?? _animationSeconds;
      final pose = penguin.companion.positionAt(time);
      final dx = eye.x - pose.x;
      final dz = eye.z - pose.z;
      penguin.root.visible =
          visible &&
          dx * dx + eye.y * eye.y + dz * dz <= visibleRange * visibleRange;
      if (!penguin.root.visible) continue;
      penguin.pose(time);
      _hasVisibleMotion |= animate;
    }
  }

  void dispose() {
    _disposed = true;
    root.parent?.remove(root);
    _hasVisibleMotion = false;
  }
}

class _Penguin {
  _Penguin(Node model, {required this.companion}) {
    root.add(model);
    // Node.clone rebinds skins but does not copy picking flags. All surfaces
    // use the same skeleton, so also share one joint upload per character.
    final skin = model.getChildByName('body-surface')!.skin;
    for (final surface in model.children.where((node) => node.mesh != null)) {
      surface
        ..raycastable = false
        ..skin = skin;
    }
    Node joint(String name) => model.getChildByName(name)!;
    pelvis = joint('pelvis');
    spine = joint('spine');
    head = joint('head');
    final compact = companion.build == CharacterBuild.compact;
    final upright = companion.build == CharacterBuild.upright;
    // Only the upper body morphs. Uniform head scaling carries the eyes,
    // eyelids and beak together after morphing, leaving leg lengths unchanged.
    head.position += Vector3(0, compact ? -0.07 : (upright ? 0.06 : 0), 0);
    head.scale = Vector3.all(compact ? 1.03 : 1);
    final buildWeights = switch (companion.build) {
      CharacterBuild.standard => const [0.0, 0.0],
      CharacterBuild.compact => const [1.0, 0.0],
      CharacterBuild.upright => const [0.0, 1.0],
    };
    for (final name in ['body', 'belly']) {
      model.getChildByName('$name-surface')!.setMorphWeights(buildWeights);
    }
    lids = model.getChildByName('lids-surface')!;
    pelvisRest = pelvis.position.clone();
    for (final side in ['left', 'right']) {
      final gaze = joint('$side-gaze');
      gazes.add(gaze);
      gazeRest.add(gaze.position.clone());
      flippers.add(joint('$side-flipper'));
      flipperTips.add(joint('$side-flipper-tip'));
      legs.add(
        CharacterLimb(
          joint('$side-hip'),
          joint('$side-knee'),
          joint('$side-ankle'),
        ),
      );
    }
  }

  final CharacterCompanion companion;
  CharacterGait get gait => companion.gait;
  final root = Node(name: 'penguin');
  late final Node pelvis;
  late final Node spine;
  late final Node head;
  late final Node lids;
  late final Vector3 pelvisRest;
  final List<Node> gazes = [];
  final List<Vector3> gazeRest = [];
  final List<Node> flippers = [];
  final List<Node> flipperTips = [];
  final List<CharacterLimb> legs = [];

  void pose(double seconds) {
    final pose = gait.at(seconds);
    final phase = pose.cycle;
    final scale = gait.scale;
    root.localTransform =
        Matrix4.translation(
            Vector3(pose.root.x, gait.loop.ground, pose.root.z),
          )
          ..rotateY(pose.root.yaw)
          ..scaleByDouble(scale, scale, scale, 1);
    final waddle = math.sin(phase);
    final weight = pose.weightShift;
    final attention = companion.attentionAt(seconds);
    lids.setMorphWeight(0, companion.blinkAt(seconds));
    // Both pupils and catchlights follow one bounded gaze direction. The
    // mouth seam is head-bound and never moves with these two facial joints.
    for (var i = 0; i < gazes.length; i++) {
      gazes[i].position =
          gazeRest[i] +
          Vector3(
            0.12 * math.sin(attention.eyeYaw),
            0,
            -0.10 * (1 - math.cos(attention.eyeYaw)),
          );
    }
    pelvis.position =
        pelvisRest + Vector3(0.065 * weight, pose.bounce / scale, 0);
    // Short steps shift weight over the supporting foot. The head counters
    // the torso roll; flippers spread for balance and their tips follow.
    pelvis.rotation = Quaternion.euler(0.02 * waddle, 0, -0.035 * weight);
    spine.rotation = Quaternion.euler(
      -0.03 * waddle,
      0.055,
      pose.bank - 0.065 * weight,
    );
    head.rotation = Quaternion.euler(
      attention.yaw + 0.012 * math.sin(phase - 0.25),
      -0.055 + attention.nod,
      -pose.bank * 0.65 + 0.08 * weight,
    );
    for (var i = 0; i < flippers.length; i++) {
      final flipperPhase = phase + i * math.pi;
      final side = i == 0 ? -1.0 : 1.0;
      flippers[i].rotation = Quaternion.euler(
        side * 0.10,
        0.09 * math.sin(flipperPhase),
        side * (0.20 + 0.04 * math.cos(flipperPhase)) - pose.bank * 0.3,
      );
      final delayed = flipperPhase - 2 * math.pi * 0.08 / gait.period;
      flipperTips[i].rotation = Quaternion.euler(
        0,
        0.045 * math.sin(delayed),
        side * 0.05 * math.sin(delayed),
      );
    }
    final forward = Vector3(
      math.sin(pose.root.yaw),
      0,
      math.cos(pose.root.yaw),
    );
    legs[0].solve(pose.left, forward: forward, scale: scale);
    legs[1].solve(pose.right, forward: forward, scale: scale);
  }
}
