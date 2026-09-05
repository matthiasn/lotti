import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Size, SizedBox;
import 'package:flutter_scene/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/scene/plaza_picker.dart';
import 'package:vector_math/vector_math.dart';

/// Supplies the same CPU attributes the raycaster reads after a GPU upload.
class _RayTriangle extends UnskinnedGeometry {
  @override
  ({
    int indexCount,
    gpu.IndexType indexType,
    Null indices,
    Float32List positions,
    Null texCoords,
    int vertexCount,
    Null vertices,
  })
  get cpuMeshData => (
    vertices: null,
    positions: Float32List.fromList([-1, -1, 0, 1, -1, 0, 0, 1, 0]),
    texCoords: null,
    indices: null,
    indexType: gpu.IndexType.int16,
    vertexCount: 3,
    indexCount: 0,
  );
}

void main() {
  test('widget captures do not hide backings from navigation rays', () {
    final root = Node();
    Node surface(double z) => Node(
      localTransform: Matrix4.translationValues(0, 0, z),
      mesh: Mesh(_RayTriangle(), UnlitMaterial()),
    );
    final backing = surface(2);
    final host = surface(1)
      ..addComponent(
        WidgetComponent.bindOnly(
          child: const SizedBox(),
          size: const Size(100, 100),
          bind: (_) {},
          input: WidgetInput.manual,
        ),
      );
    root
      ..add(backing)
      ..add(host);
    final ray = Ray.originDirection(Vector3.zero(), Vector3(0, 0, 1));
    expect(raycastNode(root, ray)!.node, same(host));
    expect(PlazaPicker.navigationHit(root, ray)!.node, same(backing));

    final wall = surface(0.5);
    root.add(wall);
    expect(
      PlazaPicker.navigationHit(root, ray)!.node,
      same(wall),
      reason: 'an unrelated solid must still block navigation',
    );
    wall.visible = false;
    expect(PlazaPicker.navigationHit(root, ray)!.node, same(backing));
    backing.localTransform = Matrix4.translationValues(0, 0, 161);
    expect(PlazaPicker.navigationHit(root, ray), isNull);
    host.removeComponent(host.getComponent<WidgetComponent>()!);
  });
}
