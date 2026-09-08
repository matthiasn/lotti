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

  void tick(double seconds, {bool animate = true, bool visible = true}) =>
      characters.update(
        seconds: seconds,
        eye: Vector3(0, 2, 0),
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
      tick(3.3);
      final rig = characters.root.children.first;
      final lowHead = rig
          .getChildByName('head')!
          .globalTransform
          .getTranslation();
      final rear = rig
          .getChildByName('left-ankle')!
          .globalTransform
          .getTranslation();
      tick(5);
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
}
