import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
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
  }) {
    final last = _lastSeconds;
    _lastSeconds = seconds;
    if (animate && last != null) {
      _animationSeconds += math.max(0, seconds - last);
    }
    _hasVisibleMotion = false;
    for (final penguin in _penguins) {
      final pose = penguin.companion.positionAt(_animationSeconds);
      final dx = eye.x - pose.x;
      final dz = eye.z - pose.z;
      penguin.root.visible =
          dx * dx + eye.y * eye.y + dz * dz <= visibleRange * visibleRange;
      if (!penguin.root.visible) continue;
      penguin.pose(_animationSeconds);
      _hasVisibleMotion |= animate;
    }
  }

  void dispose() {
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
    pelvisRest = pelvis.position.clone();
    for (final side in ['left', 'right']) {
      flippers.add(joint('$side-flipper'));
      flipperTips.add(joint('$side-flipper-tip'));
      legs.add(
        _Leg(joint('$side-hip'), joint('$side-knee'), joint('$side-ankle')),
      );
    }
  }

  final CharacterCompanion companion;
  CharacterGait get gait => companion.gait;
  final root = Node(name: 'penguin');
  late final Node pelvis;
  late final Node spine;
  late final Node head;
  late final Vector3 pelvisRest;
  final List<Node> flippers = [];
  final List<Node> flipperTips = [];
  final List<_Leg> legs = [];

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
        0.14 * math.sin(flipperPhase),
        side * (0.28 + 0.07 * math.cos(flipperPhase)) - pose.bank * 0.3,
      );
      flipperTips[i].rotation = Quaternion.euler(
        0,
        0.07 * math.sin(flipperPhase - 0.4),
        side * 0.08 * math.sin(flipperPhase - 0.5),
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

/// Analytic two-bone IK in world space, including lateral movement on turns.
/// Each rotation maps the authored rest vector onto the solved limb vector;
/// the ankle cancels its parents so the planted sole keeps its ground pose.
class _Leg {
  _Leg(this.hip, this.knee, this.ankle)
    : upper = knee.position.clone(),
      lower = ankle.position.clone();

  final Node hip;
  final Node knee;
  final Node ankle;
  final Vector3 upper;
  final Vector3 lower;

  static Quaternion _rotation(Node node) {
    final rotation = Quaternion.identity();
    node.globalTransform.decompose(Vector3.zero(), rotation, Vector3.zero());
    return rotation;
  }

  /// Unlike fromTwoVectors, retain small rotations: snapping even a degree
  /// at a knee makes a planted foot visibly skid.
  static Quaternion _align(Vector3 from, Vector3 to) {
    final a = from.normalized();
    final b = to.normalized();
    final cross = a.cross(b);
    return Quaternion(cross.x, cross.y, cross.z, 1 + a.dot(b))..normalize();
  }

  void solve(
    CharacterFootPose foot, {
    required Vector3 forward,
    required double scale,
  }) {
    final origin = hip.globalTransform.getTranslation();
    final target = Vector3(foot.x, foot.y, foot.z);
    final delta = target - origin;
    final a = upper.length * scale;
    final b = lower.length * scale;
    final distance = delta.length.clamp((a - b).abs() + 1e-6, a + b - 1e-6);
    final direction = delta.normalized();
    final bend = (forward - direction * forward.dot(direction)).normalized();
    final along = (a * a - b * b + distance * distance) / (2 * distance);
    final rise = math.sqrt(math.max(0, a * a - along * along));
    final wantedKnee = origin + direction * along + bend * rise;
    final parentRotation = _rotation(hip.parent!);
    // vector_math's Quaternion.rotated applies q^-1 * v * q: this converts
    // world vectors into the parent's local frame without conjugating q.
    final localUpper = parentRotation.rotated(wantedKnee - origin);
    hip.rotation = _align(upper, localUpper);
    final kneeOrigin = knee.globalTransform.getTranslation();
    final localLower = _rotation(hip).rotated(target - kneeOrigin);
    knee.rotation = _align(lower, localLower);
    final desired =
        Quaternion.axisAngle(Vector3(0, 1, 0), foot.yaw) *
        Quaternion.axisAngle(Vector3(1, 0, 0), foot.pitch);
    ankle.rotation = _rotation(knee).conjugated() * desired;
  }
}
