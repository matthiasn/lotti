import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/scene/plaza_boxes.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  late PlazaBoxes boxes;

  setUp(() {
    // Empty geometry needs no GPU upload; bounds suffice to verify placement.
    Geometry unitBox() => UnskinnedGeometry()
      ..setLocalBounds(Aabb3.minMax(Vector3.all(-0.5), Vector3.all(0.5)), null);
    boxes = PlazaBoxes(cube: unitBox(), shadedCube: unitBox());
  });

  test(
    'different sizes share geometry and equal solid colours share material',
    () {
      final a = boxes.node(Vector3(2, 3, 4), boxes.solid(Vector4(1, 0, 0, 1)));
      final b = boxes.node(Vector3(7, 8, 9), boxes.solid(Vector4(1, 0, 0, 1)));
      final aMesh = a.children.single.mesh!;
      final bMesh = b.children.single.mesh!;
      expect(
        aMesh.primitives.single.geometry,
        same(bMesh.primitives.single.geometry),
      );
      expect(
        aMesh.primitives.single.material,
        same(bMesh.primitives.single.material),
      );
      expect(a.children.single.localTransform.entry(0, 0), 2);
      expect(b.children.single.localTransform.entry(0, 0), 7);
    },
  );

  test('shaded boxes share their own geometry and retain the material', () {
    final material = boxes.solid(Vector4(0.1, 0.2, 0.3, 1));
    final a = boxes.node(Vector3(2, 3, 4), material, shaded: true);
    final b = boxes.node(Vector3.all(5), material, shaded: true);
    expect(
      a.children.single.mesh!.primitives.single.geometry,
      same(boxes.shadedCube),
    );
    expect(
      b.children.single.mesh!.primitives.single.geometry,
      same(boxes.shadedCube),
    );
    expect(boxes.shadedCube, isNot(same(boxes.cube)));
    expect(a.children.single.mesh!.primitives.single.material, same(material));
  });

  test('mesh scale preserves rotated parent and attached child positions', () {
    final pose = Matrix4.translation(Vector3(10, 20, 30))..rotateY(math.pi / 2);
    final anchor = boxes.node(
      Vector3(2, 4, 6),
      boxes.solid(Vector4.all(1)),
      transform: pose,
    );
    final mesh = anchor.children.single;
    final child = Node(localTransform: Matrix4.translation(Vector3(0, 2.7, 1)));
    anchor.add(child);
    final position = child.globalTransform.getTranslation();
    expect(position.x, closeTo(11, 1e-5));
    expect(position.y, closeTo(22.7, 1e-5));
    expect(position.z, closeTo(30, 1e-5));
    final corner = mesh.globalTransform.transform3(Vector3.all(0.5));
    expect(corner.x, closeTo(13, 1e-5));
    expect(corner.y, closeTo(22, 1e-5));
    expect(corner.z, closeTo(29, 1e-5));
    // The picker walks from the mesh to this same logical anchor.
    expect(mesh.parent, same(anchor));
  });

  test(
    'solid cache distinguishes alpha and depth bias, and owns its colour',
    () {
      final color = Vector4(0.1, 0.2, 0.3, 1);
      final solid = boxes.solid(color);
      final biased = boxes.solid(color, depthBias: 0.05);
      final faded = boxes.solid(Vector4(0.1, 0.2, 0.3, 0.5));
      color.x = 0.9;
      expect(solid.baseColorFactor.x, closeTo(0.1, 1e-6));
      expect(biased, isNot(same(solid)));
      expect(biased.depthBias, 0.05);
      expect(faded, isNot(same(solid)));
      expect(faded.baseColorFactor.w, 0.5);
      expect(boxes.solid(Vector4(0.1, 0.2, 0.3, 1)), same(solid));
      final otherScene = PlazaBoxes(
        cube: boxes.cube,
        shadedCube: boxes.shadedCube,
      );
      expect(otherScene.solid(Vector4(0.1, 0.2, 0.3, 1)), isNot(same(solid)));
    },
  );
}
