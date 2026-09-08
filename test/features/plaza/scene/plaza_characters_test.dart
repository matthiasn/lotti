import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/domain/character_loop.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
import 'package:lotti/features/plaza/scene/plaza_characters.dart';
import 'package:lotti/features/plaza/scene/plaza_primitives.dart';
import 'package:vector_math/vector_math.dart';

import 'test_utils.dart';

Iterable<Node> _nodes(Node root) sync* {
  yield root;
  for (final child in root.children) {
    yield* _nodes(child);
  }
}

void main() {
  const loop = CharacterLoop(
    x: 0,
    z: 0,
    heading: 0,
    radius: 6,
    halfStraight: 6,
  );
  late Node parent;
  late Node model;
  late PlazaCharacters characters;

  setUp(() {
    parent = Node();
    model = loadPenguinWithoutGpu();
    PlazaCharacters.styleModel(model);
    characters = PlazaCharacters(
      parent: parent,
      population: [
        for (final (i, scale) in [1.0, 0.88, 0.96, 0.82].indexed)
          CharacterCompanion(
            id: 'test-$i',
            region: 'test',
            build: CharacterBuild.values[i % CharacterBuild.values.length],
            gait: CharacterGait(loop: loop, scale: scale, phase: i / 4 + 0.05),
          ),
      ],
      model: model,
    );
  });

  tearDown(() => characters.dispose());

  void tick(double seconds, {bool animate = true, Vector3? eye}) =>
      characters.update(
        seconds: seconds,
        eye: eye ?? Vector3(0, 2, 0),
        animate: animate,
      );

  test(
    'visibility pauses rigs immediately and resumes without a catch-up jump',
    () {
      tick(10);
      tick(11);
      final nodes = _nodes(characters.root).toList();
      final transforms = [
        for (final node in nodes) node.localTransform.clone(),
      ];
      expect(characters.hasVisibleMotion, isTrue);
      characters.enabled = false;
      expect(characters.enabled, isFalse);
      expect(characters.root.visible, isFalse);
      expect(characters.hasVisibleMotion, isFalse);
      tick(1000);
      characters
        ..enabled = false
        ..enabled = true;
      expect(characters.root.visible, isTrue);
      tick(2000);
      expect(_nodes(characters.root), nodes);
      for (var i = 0; i < nodes.length; i++) {
        expect(nodes[i].localTransform, transforms[i]);
      }
      tick(2000.1);
      expect(nodes[1].localTransform, isNot(transforms[1]));
      characters
        ..enabled = false
        ..dispose()
        ..enabled = true;
      tick(3000);
      expect(characters.root.parent, isNull);
      expect(characters.hasVisibleMotion, isFalse);
      expect(characters.enabled, isFalse);
    },
  );

  test(
    'four rigs share geometry and token materials without blocking taps',
    () {
      expect(characters.root.children, hasLength(4));
      final parts = _nodes(
        characters.root,
      ).where((n) => n.mesh != null).toList();
      expect(parts, isNotEmpty);
      final materials = <Material>{};
      for (final part in parts) {
        expect(part.raycastable, isFalse);
        final primitive = part.mesh!.primitives.single;
        final source = model.getChildByName(part.name)!;
        expect(
          primitive.geometry,
          same(source.mesh!.primitives.single.geometry),
        );
        expect(part.skin, isNot(same(source.skin)));
        expect(part.skin!.joints, hasLength(15));
        final actor = part.parent!.parent!;
        for (final joint in part.skin!.joints) {
          expect(_nodes(actor), contains(joint));
        }
        materials.add(primitive.material);
      }
      expect(materials, hasLength(8));
      final torso = parts.firstWhere((n) => n.name == 'body-surface');
      final material =
          torso.mesh!.primitives.single.material as PhysicallyBasedMaterial;
      expect(
        material.baseColorFactor,
        linearColor(dsTokensDark.colors.background.level02),
      );
      expect(material.metallicFactor, 0);
      final eye = parts.firstWhere((n) => n.name == 'eyes-surface');
      final pupil = parts.firstWhere((n) => n.name == 'pupils-surface');
      final eyeMaterial =
          eye.mesh!.primitives.single.material as PhysicallyBasedMaterial;
      final pupilMaterial =
          pupil.mesh!.primitives.single.material as PhysicallyBasedMaterial;
      expect(eyeMaterial.baseColorFactor, Vector4.all(1));
      expect(pupilMaterial.baseColorFactor.x, lessThan(0.05));
    },
  );

  test('body builds and expressions vary while geometry stays shared', () {
    final rigs = characters.root.children.toList();
    final bodies = [
      for (final rig in rigs) rig.getChildByName('body-surface')!,
    ];
    expect(bodies[0].morphWeights, [0, 0]);
    expect(bodies[1].morphWeights, [1, 0]);
    expect(bodies[2].morphWeights, [0, 1]);
    final shape = bodies.first.mesh!.morphTargets!;
    expect(shape.targetNames, ['compact', 'upright']);
    expect(shape.positionDeltas.any((v) => v.abs() > 0.02), isTrue);
    expect(shape.normalDeltas!.any((v) => v.abs() > 0.01), isTrue);
    expect(
      rigs[1].getChildByName('head')!.position.y,
      lessThan(rigs[0].getChildByName('head')!.position.y - 0.06),
    );
    expect(
      rigs[2].getChildByName('head')!.position.y,
      greaterThan(rigs[0].getChildByName('head')!.position.y + 0.05),
    );
    final lid = rigs[0].getChildByName('lids-surface')!;
    final other = rigs[1].getChildByName('lids-surface')!;
    lid.setMorphWeight(0, 1);
    expect(lid.morphWeights, [1]);
    expect(other.morphWeights, [0]);
    expect(model.getChildByName('lids-surface')!.morphWeights, [0]);
    expect(
      lid.mesh!.primitives.single.geometry,
      same(other.mesh!.primitives.single.geometry),
    );
  });

  test('eyes lead a glance and closed eyelids pause without catching up', () {
    const gait = CharacterGait(loop: loop, scale: 1, phase: 0);
    characters.dispose();
    final companion = CharacterCompanion(
      id: 'expression-0',
      region: 'test',
      gait: gait,
      partnerLoop: loop.translated(CharacterPopulation.pairSeparation),
    );
    characters = PlazaCharacters(
      parent: parent,
      model: model,
      population: [companion],
    );
    final rig = characters.root.children.single;
    final gaze = rig.getChildByName('left-gaze')!;
    final lids = rig.getChildByName('lids-surface')!;
    tick(0);
    final forward = gaze.position.clone();
    tick(0.04);
    expect(gaze.position.x, greaterThan(forward.x + 0.001));
    expect(gaze.position.y, forward.y);
    var closed = false;
    for (var frame = 5; frame < 1800; frame++) {
      tick(frame / 100);
      if (lids.morphWeights!.single > 0.999) {
        closed = true;
        break;
      }
    }
    expect(closed, isTrue, reason: 'the rig must actually close its eyelids');
    final held = lids.morphWeights;
    final gazeHeld = gaze.localTransform.clone();
    tick(100, animate: false);
    tick(600, animate: false);
    expect(lids.morphWeights, held);
    expect(gaze.localTransform, gazeHeld);
    tick(600.01);
    expect(lids.morphWeights!.single, greaterThan(0.9));
    tick(600.3);
    expect(lids.morphWeights!.single, lessThan(0.01));
  });

  test('travel and articulation advance without replacing meshes or nodes', () {
    tick(100);
    final before = _nodes(characters.root).toList();
    final penguin = characters.root.children.first;
    final position = penguin.position;
    final joints = before
        .where(
          (n) => {
            'left-hip',
            'left-flipper',
            'left-flipper-tip',
            'spine',
            'head',
          }.contains(n.name),
        )
        .toList();
    final transforms = [for (final node in joints) node.localTransform.clone()];
    expect(joints, hasLength(20));
    tick(100.1);
    expect(
      penguin.position.distanceTo(position),
      closeTo(CharacterLoop.speed * 0.1, 0.001),
    );
    for (var i = 0; i < joints.length; i++) {
      expect(joints[i].localTransform, isNot(transforms[i]));
    }
    expect(_nodes(characters.root).toList(), before);
    expect(characters.hasVisibleMotion, isTrue);
  });

  test(
    'penguins have tuxedo plumage, flippers and an orange bill and feet',
    () {
      final penguin = characters.root.children.first;
      Vector4 color(String name) =>
          (penguin
                      .getChildByName('$name-surface')!
                      .mesh!
                      .primitives
                      .single
                      .material
                  as PhysicallyBasedMaterial)
              .baseColorFactor;
      expect(
        color('body'),
        linearColor(dsTokensDark.colors.background.level02),
      );
      expect(
        color('belly'),
        linearColor(dsTokensLight.colors.background.level01),
      );
      expect(
        color('beak'),
        linearColor(dsTokensDark.colors.alert.warning.defaultColor),
      );
      expect(color('feet'), color('beak'));
      expect(penguin.getChildByName('left-flipper')!.position.x, lessThan(0));
      expect(
        penguin.getChildByName('right-flipper')!.position.x,
        greaterThan(0),
      );
      expect(penguin.getChildByName('tail-tip'), isNull);
      expect(penguin.getChildByName('left-wrist'), isNull);
    },
  );

  for (final street in [false, true]) {
    test(
      'IK reaches both feet on ${street ? 'tight street bends' : 'the plaza'} at every scale',
      () {
        final route = street
            ? const CharacterLoop(
                x: 0,
                z: 0,
                heading: -math.pi / 2,
                radius: 2.45,
                halfStraight: 5,
                pace: 1.17,
                ground: CharacterPopulation.streetGround,
              )
            : loop;
        final cast = [
          for (final build in CharacterBuild.values)
            for (final (i, scale) in [1.0, 0.88, 0.96, 0.82].indexed)
              CharacterCompanion(
                id: '${build.name}-$i',
                region: 'test',
                build: build,
                gait: CharacterGait(
                  loop: route,
                  scale: scale,
                  phase: i / 4 + 0.05,
                  stepPhase: street ? 0.31 : 0,
                ),
              ),
        ];
        characters.dispose();
        characters = PlazaCharacters(
          parent: parent,
          population: cast,
          model: model,
        );
        tick(0);
        for (var frame = 0; frame < 600; frame++) {
          final seconds = frame / 600 * route.length / route.pace;
          tick(seconds);
          for (final (i, companion) in cast.indexed) {
            final scale = companion.gait.scale;
            final penguin = characters.root.children[i];
            final gait = cast[i].gait.at(seconds);
            for (final (name, target) in [
              ('left-ankle', gait.left),
              ('right-ankle', gait.right),
            ]) {
              final ankle = penguin.getChildByName(name)!;
              final actual = ankle.globalTransform.getTranslation();
              expect(
                actual.distanceTo(Vector3(target.x, target.y, target.z)),
                lessThan(2e-5),
                reason: 'frame $frame actor $i $name',
              );
              final up = ankle.globalTransform.getColumn(1);
              expect(up.y, closeTo(scale * math.cos(target.pitch), 2e-5));
              if (target.planted) {
                expect(up.x, closeTo(0, 2e-5));
                expect(up.z, closeTo(0, 2e-5));
              }
            }
          }
        }
      },
    );
  }

  test(
    'reduced motion freezes every joint and resumes without catching up',
    () {
      tick(10);
      tick(10.2);
      final nodes = _nodes(characters.root).toList();
      final frozen = [for (final node in nodes) node.localTransform.clone()];
      tick(200, animate: false);
      tick(600, animate: false);
      expect(characters.hasVisibleMotion, isFalse);
      for (var i = 0; i < nodes.length; i++) {
        expect(nodes[i].localTransform, frozen[i]);
      }
      final before = characters.root.children.first.position;
      tick(600.1);
      expect(
        characters.root.children.first.position.distanceTo(before),
        closeTo(CharacterLoop.speed * 0.1, 0.001),
      );
      expect(characters.hasVisibleMotion, isTrue);
    },
  );

  test(
    'distant rigs leave the animation frame budget and reappear in place',
    () {
      tick(0);
      tick(1, eye: Vector3(0, 200, 0));
      expect(characters.hasVisibleMotion, isFalse);
      expect(characters.root.children.every((n) => !n.visible), isTrue);
      tick(2);
      expect(characters.hasVisibleMotion, isTrue);
      expect(characters.root.children.every((n) => n.visible), isTrue);
      final expected = loop.at(2, phase: 0.05);
      final actual = characters.root.children.first.position;
      expect(actual.x, closeTo(expected.x, 1e-5));
      expect(actual.z, closeTo(expected.z, 1e-5));
      characters.dispose();
      expect(parent.children, isEmpty);
      expect(characters.hasVisibleMotion, isFalse);
    },
  );

  test('a planted foot stays fixed while the body travels past it', () {
    tick(0);
    final phaseTravel = loop.length * 0.05;
    final contactTravel =
        (phaseTravel / CharacterGait.strideLength).ceil() *
            CharacterGait.strideLength +
        CharacterGait.strideLength * 0.1;
    final seconds = (contactTravel - phaseTravel) / CharacterLoop.speed;
    tick(seconds);
    final ankle = _nodes(
      characters.root.children.first,
    ).firstWhere((node) => node.name == 'left-ankle');
    final planted = ankle.globalTransform.getTranslation();
    tick(seconds + 0.025);
    final later = ankle.globalTransform.getTranslation();
    expect(
      planted.y,
      closeTo(loop.ground + CharacterGait.ankleHeight, 1e-5),
    );
    expect(later.distanceTo(planted), lessThan(1e-5));
  });

  test(
    'conversation turns the head, preserves footsteps and pauses with travel',
    () {
      const gait = CharacterGait(loop: loop, scale: 1, phase: 0);
      characters.dispose();
      characters = PlazaCharacters(
        parent: parent,
        model: model,
        population: [
          CharacterCompanion(
            id: 'talking',
            region: 'test',
            gait: gait,
            partnerLoop: loop.translated(CharacterPopulation.pairSeparation),
          ),
          const CharacterCompanion(id: 'quiet', region: 'test', gait: gait),
        ],
      );
      expect(characters.root.children, hasLength(2));
      final talking = characters.root.children.first;
      final quiet = characters.root.children.last;
      final head = talking.getChildByName('head')!;
      final quietHead = quiet.getChildByName('head')!;
      tick(0);
      tick(0.45);
      // +Z is forward and +X points toward this partner. The glance is a head
      // turn, not a lateral roll or a change to either foot's contact target.
      expect(
        head.globalTransform.getColumn(2).x,
        greaterThan(quietHead.globalTransform.getColumn(2).x + 0.3),
      );
      for (final joint in ['pelvis', 'left-ankle', 'right-ankle']) {
        expect(
          talking.getChildByName(joint)!.globalTransform,
          quiet.getChildByName(joint)!.globalTransform,
        );
      }
      final held = head.localTransform.clone();
      tick(100, animate: false);
      tick(500, animate: false);
      expect(head.localTransform, held);
      tick(500.1);
      expect(head.localTransform, isNot(held));
      tick(505);
      expect(head.localTransform, quietHead.localTransform);
    },
  );

  test('a missing route needs no GPU resources or recurring motion', () {
    final emptyParent = Node();
    final empty = PlazaCharacters(
      parent: emptyParent,
      population: const [],
      model: null,
    )..update(seconds: 10, eye: Vector3.zero(), animate: true);
    expect(emptyParent.children, isEmpty);
    expect(empty.hasVisibleMotion, isFalse);
    empty.dispose();
  });
}
