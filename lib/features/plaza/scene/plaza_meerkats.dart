import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/meerkat_motion.dart';
import 'package:lotti/features/plaza/scene/character_limb.dart';
import 'package:lotti/features/plaza/scene/plaza_primitives.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:vector_math/vector_math.dart';

/// Four-pawed meerkats with separate visibility and independent behaviour.
/// A clone owns its joints and blink weight while sharing geometry/materials.
class PlazaMeerkats {
  PlazaMeerkats({
    required Node parent,
    required Node? model,
    required List<MeerkatMotion> population,
    Texture2D? shadowTexture,
  }) {
    if (model == null || population.isEmpty) return;
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
    for (final motion in population) {
      final meerkat = _Meerkat(model.clone(), motion);
      _meerkats.add(meerkat);
      root.add(meerkat.root);
      if (shadow != null) {
        meerkat.root.add(
          Node(mesh: shadow, name: 'contact-shadow')
            ..raycastable = false
            ..localTransform = (Matrix4.translationValues(0, 0.003, 0)
              ..rotateX(-math.pi / 2)),
        );
      }
      meerkat.pose(0);
    }
    parent.add(root);
  }

  static const asset = 'assets/plaza/meerkat.glb';
  static const visibleRange = 90.0;
  final root = Node(name: 'plaza-meerkats');
  final List<_Meerkat> _meerkats = [];
  double? _lastSeconds;
  double _animationSeconds = 0;
  bool _hasVisibleMotion = false;
  bool get hasVisibleMotion => _hasVisibleMotion;

  static Future<Node> loadModel() async {
    final imported = await Node.fromGlbAsset(asset);
    final model = imported.getChildByName('meerkat-model')!;
    model.parent?.remove(model);
    styleModel(model);
    return model;
  }

  /// Tawny fur reuses the world's existing warm neutral lamp palette.
  static void styleModel(Node model) {
    final fur = PlazaStyle.lantern(LanternState.open);
    final colors = {
      'fur': fur,
      'belly': dsTokensLight.colors.background.level02,
      'mask': dsTokensDark.colors.background.level02,
      'eyes': dsTokensLight.colors.background.level01,
      'pupils': dsTokensDark.colors.background.level01,
      'lids': fur,
    };
    for (final entry in colors.entries) {
      final surface = model.getChildByName('${entry.key}-surface')!
        ..raycastable = false;
      for (final primitive in surface.mesh!.primitives) {
        (primitive.material as PhysicallyBasedMaterial).baseColorFactor =
            linearColor(entry.value);
      }
    }
  }

  void update({
    required double seconds,
    required Vector3 eye,
    required bool animate,
    bool visible = true,
    double Function(String id)? clockFor,
  }) {
    final previous = _lastSeconds;
    _lastSeconds = seconds;
    if (animate && previous != null) {
      _animationSeconds += math.max(0, seconds - previous);
    }
    _hasVisibleMotion = false;
    for (final meerkat in _meerkats) {
      final time = clockFor?.call(meerkat.motion.id) ?? _animationSeconds;
      final pose = meerkat.motion.at(time);
      final dx = pose.root.x - eye.x;
      final dz = pose.root.z - eye.z;
      meerkat.root.visible =
          visible &&
          dx * dx + eye.y * eye.y + dz * dz <= visibleRange * visibleRange;
      if (!meerkat.root.visible) continue;
      meerkat.pose(time);
      _hasVisibleMotion |= animate;
    }
  }

  void dispose() {
    root.parent?.remove(root);
    _hasVisibleMotion = false;
  }
}

class _Meerkat {
  _Meerkat(Node model, this.motion) {
    root.add(model);
    final skin = model.getChildByName('fur-surface')!.skin;
    for (final surface in model.children.where((n) => n.mesh != null)) {
      surface
        ..raycastable = false
        ..skin = skin;
    }
    Node joint(String name) => model.getChildByName(name)!;
    pelvis = joint('pelvis');
    spine = joint('spine');
    head = joint('head');
    lids = model.getChildByName('lids-surface')!;
    for (final side in ['left', 'right']) {
      front.add(
        CharacterLimb(
          joint('$side-shoulder'),
          joint('$side-elbow'),
          joint('$side-wrist'),
        ),
      );
      rear.add(
        CharacterLimb(
          joint('$side-hip'),
          joint('$side-knee'),
          joint('$side-ankle'),
        ),
      );
    }
    for (final name in ['tail-base', 'tail-middle', 'tail-tip']) {
      tail.add(joint(name));
    }
  }

  final MeerkatMotion motion;
  final root = Node(name: 'meerkat');
  late final Node pelvis;
  late final Node spine;
  late final Node head;
  late final Node lids;
  final List<CharacterLimb> front = [];
  final List<CharacterLimb> rear = [];
  final List<Node> tail = [];

  void pose(double seconds) {
    final pose = motion.at(seconds);
    final scale = motion.scale;
    final upright = pose.upright;
    final moving = (pose.speed / 1.7).clamp(0.0, 1.0);
    final tilt = (1 - upright) * 1.26;
    final phase = pose.cycle;
    root.localTransform =
        Matrix4.translationValues(pose.root.x, motion.loop.ground, pose.root.z)
          ..rotateY(pose.root.yaw)
          ..scaleByDouble(scale, scale, scale, 1);
    pelvis.position = Vector3(
      0.009 * math.sin(phase) * moving,
      0.44 + 0.18 * upright + 0.012 * math.sin(2 * phase) * moving,
      0,
    );
    pelvis.rotation = Quaternion.axisAngle(Vector3(1, 0, 0), tilt);
    spine.rotation = Quaternion.axisAngle(
      Vector3(0, 1, 0),
      0.018 * math.sin(phase) * moving,
    );
    head.rotation =
        Quaternion.axisAngle(Vector3(1, 0, 0), -tilt + pose.headPitch) *
        Quaternion.axisAngle(Vector3(0, 1, 0), pose.headYaw);
    lids.setMorphWeight(0, pose.blink);
    tail[0].rotation =
        Quaternion.axisAngle(Vector3(1, 0, 0), -0.3 * (1 - upright)) *
        Quaternion.axisAngle(
          Vector3(0, 1, 0),
          0.035 * math.sin(phase) * moving,
        );
    for (var i = 1; i < tail.length; i++) {
      tail[i].rotation = Quaternion.axisAngle(
        Vector3(0, 1, 0),
        0.045 * math.sin(phase - i * 0.4) * moving,
      );
    }
    final forward = Vector3(
      math.sin(pose.root.yaw),
      0,
      math.cos(pose.root.yaw),
    );
    rear[0].solve(pose.rearLeft, forward: forward, scale: scale);
    rear[1].solve(pose.rearRight, forward: forward, scale: scale);
    for (var i = 0; i < front.length; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final paw = i == 0 ? pose.frontLeft : pose.frontRight;
      final tucked = root.globalTransform.transform3(
        Vector3(side * 0.20, 1.10, 0.32),
      );
      final target = CharacterFootPose(
        x: paw.x + (tucked.x - paw.x) * upright,
        y: paw.y + (tucked.y - paw.y) * upright,
        z: paw.z + (tucked.z - paw.z) * upright,
        yaw: paw.yaw,
        pitch: paw.pitch * (1 - upright),
        planted: upright == 0 && paw.planted,
      );
      final outward = Vector3(
        side * math.cos(pose.root.yaw),
        0,
        -side * math.sin(pose.root.yaw),
      );
      front[i].solve(
        target,
        forward: -forward * (1 - upright) + outward * upright,
        scale: scale,
      );
    }
  }
}
