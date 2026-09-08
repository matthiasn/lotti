import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/meerkat_motion.dart';
import 'package:lotti/features/plaza/scene/plaza_meerkats.dart';
import 'package:vector_math/vector_math.dart';

import 'test_utils.dart';

void main() {
  const loop = CharacterLoop(
    x: 0,
    z: 0,
    heading: 0.4,
    radius: 1.1,
    halfStraight: 1.4,
  );
  late Node parent;
  late Node model;
  late PlazaMeerkats characters;
  const motions = [
    MeerkatMotion(id: 'one', loop: loop, scale: 0.68, phase: 0),
    MeerkatMotion(id: 'two', loop: loop, scale: 0.76, phase: 0.5),
  ];

  setUp(() {
    parent = Node();
    model = loadMeerkatWithoutGpu();
    PlazaMeerkats.styleModel(model);
    characters = PlazaMeerkats(
      parent: parent,
      model: model,
      population: motions,
    );
  });
  tearDown(() => characters.dispose());

  void tick(
    double seconds, {
    bool animate = true,
    bool visible = true,
    Vector3? eye,
  }) => characters.update(
    seconds: seconds,
    eye: eye ?? Vector3(0, 2, 0),
    animate: animate,
    visible: visible,
  );

  test('clones share skinned surfaces and retain independent expressions', () {
    final rigs = characters.root.children.toList();
    final a = rigs[0].getChildByName('lids-surface')!;
    final b = rigs[1].getChildByName('lids-surface')!;
    expect(a.mesh!.primitives.single.geometry, isA<MorphedSkinnedGeometry>());
    expect(
      a.mesh!.primitives.single.geometry,
      same(b.mesh!.primitives.single.geometry),
    );
    expect(a.skin!.joints, hasLength(20));
    expect(a.skin, isNot(same(b.skin)));
    a.setMorphWeight(0, 1);
    expect(a.morphWeights, [1]);
    expect(b.morphWeights, [0]);
    expect(a.mesh!.morphTargets!.positionDeltas.any((d) => d < -0.08), isTrue);
    for (final rig in rigs) {
      for (final surface in rig.children.single.children.where(
        (n) => n.mesh != null,
      )) {
        expect(surface.raycastable, isFalse);
      }
    }
  });

  test(
    'all four paws follow their contacts through scampers and tight bends',
    () {
      tick(0);
      for (var frame = 0; frame <= 2000; frame++) {
        final seconds = frame / 100;
        tick(seconds);
        for (final (i, rig) in characters.root.children.indexed) {
          final pose = motions[i].at(seconds);
          // Sentinel turns have their own planted-foot invariants below and
          // in meerkat_lookout_test; moving/foraging contacts use the gait.
          if (pose.action != MeerkatAction.scamper &&
              pose.action != MeerkatAction.forage) {
            continue;
          }
          for (final (name, paw) in [
            ('left-ankle', pose.rearLeft),
            ('right-ankle', pose.rearRight),
            if (pose.upright == 0) ...[
              ('left-wrist', pose.frontLeft),
              ('right-wrist', pose.frontRight),
            ],
          ]) {
            final actual = rig
                .getChildByName(name)!
                .globalTransform
                .getTranslation();
            expect(actual.x, closeTo(paw.x, 1e-4), reason: '$seconds $name x');
            expect(actual.y, closeTo(paw.y, 1e-4), reason: '$seconds $name y');
            expect(actual.z, closeTo(paw.z, 1e-4), reason: '$seconds $name z');
          }
        }
      }
    },
  );

  test(
    'lookout raises the head and tucks paws while hind feet stay planted',
    () {
      tick(0);
      final at = motions.first.at(3.3).root;
      final eye = Vector3(
        at.x + 5 * math.sin(at.yaw),
        2,
        at.z + 5 * math.cos(at.yaw),
      );
      tick(3.3, eye: eye);
      final rig = characters.root.children.first;
      final lowHead = rig
          .getChildByName('head')!
          .globalTransform
          .getTranslation();
      final rear = rig
          .getChildByName('left-ankle')!
          .globalTransform
          .getTranslation();
      tick(5, eye: eye);
      final highHead = rig
          .getChildByName('head')!
          .globalTransform
          .getTranslation();
      expect(highHead.y, greaterThan(lowHead.y + 0.4));
      expect(
        rig.getChildByName('left-wrist')!.globalTransform.getTranslation().y,
        greaterThan(0.7),
      );
      final planted = rig
          .getChildByName('left-ankle')!
          .globalTransform
          .getTranslation();
      expect(planted.distanceTo(rear), lessThan(1e-5));
    },
  );

  test(
    'visibility removes animation demand and reduced motion freezes the pose',
    () {
      tick(0);
      tick(5);
      final rig = characters.root.children.first;
      final held = rig.getChildByName('head')!.globalTransform.clone();
      tick(10, animate: false);
      expect(rig.getChildByName('head')!.globalTransform.storage, held.storage);
      expect(characters.hasVisibleMotion, isFalse);
      tick(10, visible: false);
      expect(characters.root.children.every((n) => !n.visible), isTrue);
      expect(characters.hasVisibleMotion, isFalse);
      tick(10);
      expect(characters.root.children.every((n) => n.visible), isTrue);
      expect(rig.getChildByName('head')!.globalTransform.storage, held.storage);
      expect(characters.hasVisibleMotion, isTrue);
      characters.dispose();
      expect(parent.children, isEmpty);
    },
  );

  for (final distanceCulled in [true, false]) {
    test(
      'resumes a ${distanceCulled ? 'distant' : 'hidden'} lookout at its new stop',
      () {
        final motion = motions.first;
        final oldPose = motion.at(5);
        for (var frame = 0; frame < 150; frame++) {
          characters.update(
            seconds: frame / 60,
            eye: Vector3(
              oldPose.root.x - 5 * math.sin(oldPose.root.yaw),
              2,
              oldPose.root.z - 5 * math.cos(oldPose.root.yaw),
            ),
            animate: true,
            clockFor: (_) => 5,
          );
        }
        const nextTime = MeerkatMotion.cycleDuration + 5;
        final next = motion.at(nextTime);
        final eye = Vector3(
          next.root.x + 5 * math.sin(next.root.yaw),
          2,
          next.root.z + 5 * math.cos(next.root.yaw),
        );
        for (var frame = 150; frame < 210; frame++) {
          characters.update(
            seconds: frame / 60,
            eye: distanceCulled ? Vector3(0, 2, 1000) : eye,
            animate: true,
            visible: distanceCulled,
            clockFor: (_) => nextTime,
          );
        }
        final rig = characters.root.children.first;
        expect(rig.visible, isFalse);
        characters.update(
          seconds: 3.5,
          eye: eye,
          animate: true,
          clockFor: (_) => nextTime,
        );
        expect(rig.visible, isTrue);
        for (final (name, paw) in [
          ('left-ankle', next.rearLeft),
          ('right-ankle', next.rearRight),
        ]) {
          final actual = rig
              .getChildByName(name)!
              .globalTransform
              .getTranslation();
          expect(
            actual.distanceTo(Vector3(paw.x, paw.y, paw.z)),
            lessThan(1e-4),
            reason:
                '$name must use the current stop on the first visible frame',
          );
        }
      },
    );
  }

  test('traffic clocks hold the actual rig and gate safe reappearance', () {
    for (final seconds in [0.0, 10.0, 20.0]) {
      characters.update(
        seconds: seconds,
        eye: Vector3(0, 2, 0),
        animate: true,
        clockFor: (id) => id == 'one' ? 3.3 : 5,
        visibleFor: (id) => id == 'one',
      );
      final rig = characters.root.children.first;
      final paw = motions.first.at(3.3).frontLeft;
      final contact = rig
          .getChildByName('left-wrist')!
          .globalTransform
          .getTranslation();
      expect(contact.distanceTo(Vector3(paw.x, paw.y, paw.z)), lessThan(1e-4));
      expect(rig.visible, isTrue);
      expect(characters.root.children.last.visible, isFalse);
    }
  });

  test(
    'sentinel faces cameras on either side with raised chin and hanging paws',
    () {
      final pose = motions.first.at(5);
      var seconds = 0.0;
      for (final offset in [math.pi, -math.pi / 2, math.pi / 2]) {
        final angle = pose.root.yaw + offset;
        final eye = Vector3(
          pose.root.x + 5 * math.sin(angle),
          2,
          pose.root.z + 5 * math.cos(angle),
        );
        for (var frame = 0; frame < 150; frame++) {
          characters.update(
            seconds: seconds,
            eye: eye,
            animate: true,
            clockFor: (_) => 5,
          );
          seconds += 1 / 60;
        }
        final rig = characters.root.children.first;
        final head = rig.getChildByName('head')!;
        final forward =
            head.globalTransform.transform3(Vector3(0, 0, 1)) -
            head.globalTransform.getTranslation();
        final direction = Vector3(math.sin(angle), 0, math.cos(angle));
        final horizontal = Vector3(forward.x, 0, forward.z).normalized();
        expect(horizontal.dot(direction), greaterThan(0.995));
        expect(
          forward.y,
          greaterThan(0),
          reason: 'chin is raised, not nose-down',
        );
        final gaze = rig.getChildByName('left-gaze')!;
        final eyePosition = gaze.globalTransform.getTranslation();
        final eyeForward =
            gaze.globalTransform.transform3(Vector3(0, 0, 1)) - eyePosition;
        expect(
          eyeForward.normalized().dot((eye - eyePosition).normalized()),
          greaterThan(0.995),
          reason: 'eyes retain the camera target under the raised chin',
        );
        for (final side in ['left', 'right']) {
          final elbow = rig
              .getChildByName('$side-elbow')!
              .globalTransform
              .getTranslation();
          final wrist = rig
              .getChildByName('$side-wrist')!
              .globalTransform
              .getTranslation();
          expect(wrist.y, lessThan(elbow.y - 0.10 * motions.first.scale));
          final fingers =
              rig
                  .getChildByName('$side-wrist')!
                  .globalTransform
                  .transform3(Vector3(0, 0, 1)) -
              wrist;
          expect(
            fingers.normalized().y,
            lessThan(-0.95),
            reason: 'digits hang toward the ground',
          );
        }
        final held = head.globalTransform.clone();
        characters.update(
          seconds: seconds + 10,
          eye: Vector3(-50, 20, -50),
          animate: false,
          clockFor: (_) => 5,
        );
        expect(head.globalTransform.storage, held.storage);
        seconds += 10;
      }
    },
  );
}
