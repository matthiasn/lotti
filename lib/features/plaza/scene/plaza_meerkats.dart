import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/meerkat_lookout.dart';
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
      'belly': fur,
      'mask': dsTokensDark.colors.background.level02,
      'eyes': dsTokensDark.colors.background.level02,
      'pupils': dsTokensDark.colors.background.level01,
      'glints': dsTokensLight.colors.background.level01,
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
    bool Function(String id)? visibleFor,
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
          (visibleFor?.call(meerkat.motion.id) ?? true) &&
          dx * dx + eye.y * eye.y + dz * dz <= visibleRange * visibleRange;
      if (!meerkat.root.visible) continue;
      meerkat.pose(
        time,
        eye: eye,
        dt: animate && previous != null ? math.max(0, seconds - previous) : 0,
      );
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
    eyes.addAll([joint('left-gaze'), joint('right-gaze')]);
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
  final List<Node> eyes = [];

  final lookout = MeerkatLookout();
  Vector3? _lastEye;

  void pose(double seconds, {Vector3? eye, double dt = 0}) {
    if (eye != null && (dt > 0 || _lastEye == null)) _lastEye = eye.clone();
    final cameraEye = _lastEye;
    final pose = motion.at(seconds);
    final scale = motion.scale;
    final facing = cameraEye == null
        ? null
        : lookout.update(
            pose: pose,
            eyeX: cameraEye.x,
            eyeZ: cameraEye.z,
            dt: dt,
            scale: scale,
          );
    final yaw = facing?.yaw ?? pose.root.yaw;
    final bearing = cameraEye == null
        ? pose.root.yaw
        : math.atan2(cameraEye.x - pose.root.x, cameraEye.z - pose.root.z);
    final cameraYaw = math.atan2(
      math.sin(bearing - yaw),
      math.cos(bearing - yaw),
    );
    final upright = pose.upright;
    final moving = (pose.speed / 1.7).clamp(0.0, 1.0);
    final tilt = (1 - upright) * 1.45 + 0.18 * pose.foraging;
    final phase = pose.cycle;
    root.localTransform =
        Matrix4.translationValues(pose.root.x, motion.loop.ground, pose.root.z)
          ..rotateY(yaw)
          ..scaleByDouble(scale, scale, scale, 1);
    pelvis.position = Vector3(
      0.009 * math.sin(phase) * moving,
      0.52 +
          0.10 * upright -
          0.06 * pose.foraging +
          0.012 * math.sin(2 * phase) * moving,
      0,
    );
    pelvis.rotation = Quaternion.axisAngle(Vector3(1, 0, 0), tilt);
    spine.rotation = Quaternion.axisAngle(
      Vector3(0, 1, 0),
      0.018 * math.sin(phase) * moving,
    );
    final headPosition = head.globalTransform.getTranslation();
    final cameraPitch = cameraEye == null
        ? pose.headPitch
        : -math
              .atan2(
                cameraEye.y - headPosition.y - 0.225 * scale,
                math.sqrt(
                  math.pow(cameraEye.x - headPosition.x, 2) +
                      math.pow(cameraEye.z - headPosition.z, 2),
                ),
              )
              .clamp(-0.45, 0.45);
    head.rotation =
        Quaternion.axisAngle(
          Vector3(1, 0, 0),
          -tilt +
              pose.headPitch * (1 - upright) +
              (cameraPitch - 0.18) * upright,
        ) *
        Quaternion.axisAngle(
          Vector3(0, 1, 0),
          cameraEye == null
              ? pose.headYaw
              : cameraYaw.clamp(-0.7, 0.7) * upright,
        );
    for (final eye in eyes) {
      eye.rotation =
          Quaternion.axisAngle(Vector3(1, 0, 0), 0.18 * upright) *
          Quaternion.axisAngle(
            Vector3(0, 1, 0),
            (cameraYaw - cameraYaw.clamp(-0.7, 0.7)).clamp(-0.12, 0.12) *
                upright,
          );
    }
    lids.setMorphWeight(0, pose.blink);
    tail[0].rotation =
        Quaternion.axisAngle(
          Vector3(1, 0, 0),
          -tilt + 0.16 * moving + 0.35 * pose.foraging,
        ) *
        Quaternion.axisAngle(
          Vector3(0, 1, 0),
          0.035 * math.sin(phase) * moving,
        );
    for (var i = 1; i < tail.length; i++) {
      tail[i].rotation =
          Quaternion.axisAngle(Vector3(1, 0, 0), 0.18 * pose.foraging) *
          Quaternion.axisAngle(
            Vector3(0, 1, 0),
            0.045 * math.sin(phase - i * 0.4) * moving,
          );
    }
    final forward = Vector3(
      math.sin(yaw),
      0,
      math.cos(yaw),
    );
    rear[0].solve(
      facing?.left ?? pose.rearLeft,
      forward: forward,
      scale: scale,
    );
    rear[1].solve(
      facing?.right ?? pose.rearRight,
      forward: forward,
      scale: scale,
    );
    for (var i = 0; i < front.length; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final paw = MeerkatLookout.rotateFoot(
        i == 0 ? pose.frontLeft : pose.frontRight,
        pose.root,
        yaw - pose.root.yaw,
      );
      final tucked = root.globalTransform.transform3(
        Vector3(side * 0.13, 1.20, 0.23),
      );
      final target = CharacterFootPose(
        x: paw.x + (tucked.x - paw.x) * upright,
        y: paw.y + (tucked.y - paw.y) * upright,
        z: paw.z + (tucked.z - paw.z) * upright,
        yaw: paw.yaw,
        pitch: paw.pitch * (1 - upright) + 1.35 * upright,
        planted: upright == 0 && paw.planted,
      );
      final outward = Vector3(
        side * math.cos(yaw),
        0,
        -side * math.sin(yaw),
      );
      front[i].solve(
        target,
        forward: -forward * (1 - upright) + outward * upright,
        scale: scale,
      );
    }
  }
}
