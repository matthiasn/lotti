import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/scene/plaza_static_meshes.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  late Map<Geometry, MeshData> data;
  late PlazaStaticMeshes batches;
  Geometry upload(MeshData mesh) {
    final geometry = UnskinnedGeometry();
    data[geometry] = mesh;
    return geometry;
  }

  Node triangle(double x, {UnlitMaterial? material}) => Node(
    localTransform: Matrix4.translationValues(x, 0, 0),
    mesh: Mesh(
      upload(
        MeshData.build(
          positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
          texCoords: Float32List.fromList([0, 0, 2, 0, 0, 3]),
        ),
      ),
      material ?? UnlitMaterial(),
    ),
  );

  setUp(() {
    data = {};
    batches = PlazaStaticMeshes(
      cellSize: 40,
      read: (geometry) => data[geometry]!,
      upload: upload,
    );
  });

  test('bakes world transforms and HDR tint while retaining UVs and picks', () {
    final root = Node(localTransform: Matrix4.translationValues(100, 0, 0));
    final parent = Node(
      localTransform: Matrix4.translationValues(5, 2, 3)..rotateY(math.pi / 2),
    );
    final a = triangle(
      1,
      material: UnlitMaterial()..baseColorFactor = Vector4(2, 0.5, 1, 1),
    );
    final b = triangle(2);
    parent
      ..add(a)
      ..add(b);
    root.add(parent);
    final expected = a.globalTransform.transform3(Vector3.zero())..x -= 100;
    expect(batches.bake(root, preserve: {}), (meshes: 2, batches: 1));
    final merged = root.children.last;
    final result = data[merged.mesh!.primitives.single.geometry]!;
    expect(result.positions.take(3), orderedEquals(expected.storage));
    expect(result.triangleCount, 2);
    expect(result.texCoords!.take(6), [0, 0, 2, 0, 0, 3]);
    expect(result.colors!.take(4), [2, 0.5, 1, 1]);
    expect(result.colors!.skip(12).take(4), [1, 1, 1, 1]);
    expect(
      merged.raycastable,
      isTrue,
      reason: 'static walls still occlude picks',
    );
    expect(parent.children, isEmpty);
    expect(
      parent.parent,
      isNull,
      reason: 'empty static branches no longer cost traversal',
    );
  });

  test(
    'keeps toggling subtrees, pick targets, transparency and cells separate',
    () {
      final root = Node();
      final toggle = Node()
        ..add(triangle(1))
        ..add(triangle(2));
      final pick = triangle(3);
      final glow = triangle(
        4,
        material: UnlitMaterial()..alphaMode = AlphaMode.blend,
      );
      final remote = triangle(100);
      root
        ..add(toggle)
        ..add(pick)
        ..add(glow)
        ..add(remote)
        ..add(triangle(5))
        ..add(triangle(6));
      expect(batches.bake(root, preserve: {toggle, pick}), (
        meshes: 2,
        batches: 1,
      ));
      expect(toggle.children.length, 2);
      expect(pick.mesh, isNotNull);
      expect(glow.mesh, isNotNull);
      expect(remote.mesh, isNotNull);
      expect(remote.parent, same(root));
      expect(root.children, contains(remote));
      expect(glow.parent, same(root));
      toggle.visible = false;
      expect(toggle.children.every((n) => n.mesh != null), isTrue);
    },
  );

  test('separates depth bias, UV transforms, raycast and layer flags', () {
    final root = Node();
    for (var i = 0; i < 2; i++) {
      root
        ..add(triangle(1))
        ..add(triangle(2, material: UnlitMaterial()..depthBias = 0.1))
        ..add(
          triangle(
            3,
            material: UnlitMaterial()..baseColorTextureTransform.scale.x = 2,
          ),
        )
        ..add(triangle(4)..raycastable = false)
        ..add(triangle(5)..layers = 2);
    }
    expect(batches.bake(root, preserve: {}), (meshes: 10, batches: 5));
    expect(root.children.where((n) => !n.raycastable).length, 1);
    expect(root.children.where((n) => n.layers == 2).length, 1);
    expect(
      root.children
          .map((n) => n.mesh!.primitives.single.material)
          .whereType<UnlitMaterial>()
          .map((m) => m.depthBias),
      contains(0.1),
    );
  });

  test('a visibility group can batch locally without losing its anchor', () {
    final root = Node();
    final group = Node(localTransform: Matrix4.translationValues(100, 0, 0))
      ..visible = false
      ..add(triangle(1))
      ..add(triangle(2));
    root.add(group);
    expect(batches.bake(root, preserve: {group}, localGroups: [group]), (
      meshes: 2,
      batches: 1,
    ));
    expect(group.parent, same(root));
    expect(group.visible, isFalse);
    final mesh = group.children.single;
    final vertices = data[mesh.mesh!.primitives.single.geometry]!.positions;
    expect(vertices.take(3), [
      1,
      0,
      0,
    ], reason: 'geometry stays relative to the toggling anchor');
    group.visible = true;
    expect(
      mesh.globalTransform
          .transform3(Vector3(vertices[0], vertices[1], vertices[2]))
          .x,
      101,
    );
  });

  test('late capture materials survive root and local batching', () {
    final root = Node();
    final local = Node();
    final capture = UnlitMaterial();
    final back = triangle(1, material: capture);
    final localBack = triangle(1, material: capture);
    root
      ..add(back)
      ..add(triangle(2))
      ..add(triangle(3))
      ..add(local);
    local
      ..add(localBack)
      ..add(triangle(2))
      ..add(triangle(3));
    expect(
      batches.bake(
        root,
        preserve: {local},
        preserveMaterials: {capture},
        localGroups: [local],
      ),
      (meshes: 4, batches: 2),
    );
    capture.baseColorFactor = Vector4(0.4, 0.4, 0.4, 1);
    for (final node in [back, localBack]) {
      expect(node.mesh!.primitives.single.material, same(capture));
      expect(node.parent, isNotNull);
    }
  });

  test('failed upload leaves the source graph intact', () {
    final root = Node()
      ..add(triangle(1))
      ..add(triangle(2));
    final original = root.children.toList();
    final failing = PlazaStaticMeshes(
      cellSize: 40,
      read: (g) => data[g]!,
      upload: (_) => throw StateError('GPU allocation failed'),
    );
    expect(() => failing.bake(root, preserve: {}), throwsStateError);
    expect(root.children, original);
    expect(original.every((n) => n.mesh != null), isTrue);
  });

  test('vertex colour weight and reflected winding survive baking', () {
    final original = MeshData.build(
      positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
      colors: Float32List.fromList(List.filled(12, 0.5)),
    );
    final result = PlazaStaticMeshes.tintAndPlace(
      original,
      Matrix4.diagonal3Values(-2, 3, 1),
      UnlitMaterial()
        ..baseColorFactor = Vector4.all(2)
        ..vertexColorWeight = 0.5,
    );
    expect(result.colors, everyElement(1.5));
    expect(result.positions, [0, 0, 0, -2, 0, 0, 0, 3, 0]);
    final face = result.triangles.single;
    expect((face.pb - face.pa).cross(face.pc - face.pa).z, greaterThan(0));
  });
}
