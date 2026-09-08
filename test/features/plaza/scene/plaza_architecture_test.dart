import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/building_architecture.dart';
import 'package:lotti/features/plaza/scene/plaza_architecture.dart';
import 'package:lotti/features/plaza/scene/plaza_boxes.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  late PlazaArchitecture builder;
  late Geometry geometry;
  late UnlitMaterial wall;
  late UnlitMaterial trim;
  late UnlitMaterial light;

  setUp(() {
    geometry = UnskinnedGeometry()
      ..setLocalBounds(Aabb3.minMax(Vector3.all(-0.5), Vector3.all(0.5)), null);
    final boxes = PlazaBoxes(cube: geometry, shadedCube: geometry);
    builder = PlazaArchitecture(boxes);
    wall = boxes.solid(Vector4(0.1, 0.1, 0.1, 1));
    trim = boxes.solid(Vector4(0.3, 0.3, 0.3, 1));
    light = boxes.solid(Vector4(0, 1, 0, 1));
  });

  for (final family in BuildingFamily.values) {
    test('$family relief fits the collider and leaves the sign clear', () {
      for (final width in [5.0, 18.0, 100.0]) {
        for (final height in [6.0, 30.0, 150.0]) {
          final kit = BuildingArchitecture.forEnvelope(
            id: 'task',
            width: width,
            depth: 12,
            height: height,
            family: family,
          );
          final cores = <BuildingVolume>[];
          final groundFloors = <bool>[];
          final root = builder.build(
            kit,
            wall: wall,
            trim: trim,
            light: light,
            onVolume: (node, volume, {required groundFloor}) {
              cores.add(volume);
              groundFloors.add(groundFloor);
            },
          );
          expect(cores, hasLength(kit.volumes.length));
          expect(groundFloors, [true, ...List.filled(cores.length - 1, false)]);
          for (final (i, core) in cores.indexed) {
            expect(core.width, lessThan(kit.volumes[i].width));
            expect(core.depth, lessThan(kit.volumes[i].depth));
            expect(core.bottom, kit.volumes[i].bottom);
          }
          var litPieces = 0;
          for (final mesh in _meshes(root)) {
            final primitive = mesh.mesh!.primitives.single;
            expect(primitive.geometry, same(geometry));
            expect(
              primitive.material,
              anyOf(same(wall), same(trim), same(light)),
            );
            final bounds = _bounds(mesh);
            expect(bounds.min.x, greaterThanOrEqualTo(-width / 2 - 1e-5));
            expect(bounds.max.x, lessThanOrEqualTo(width / 2 + 1e-5));
            expect(bounds.min.z, greaterThanOrEqualTo(-6 - 1e-5));
            expect(bounds.max.z, lessThanOrEqualTo(6 + 1e-5));
            expect(bounds.min.y, greaterThanOrEqualTo(-1e-5));
            expect(bounds.max.y, lessThanOrEqualTo(height + 1e-5));
            // Actual task posters sit just outside the reserved street plane.
            expect(bounds.max.z, lessThan(kit.front + 0.03));
            if (identical(primitive.material, light)) litPieces++;
          }
          expect(litPieces, greaterThanOrEqualTo(8));
          // Geometry density cannot scale with an arbitrary plot's dimensions.
          expect(_meshes(root).length, lessThan(180));
        }
      }
    });
  }

  test('distant recipe preserves wall and crown, omitting column detail', () {
    final kit = BuildingArchitecture.forEnvelope(
      id: 'landmark',
      width: 30,
      depth: 20,
      height: 80,
    );
    Node build({required bool detailed}) => builder.build(
      kit,
      wall: wall,
      trim: trim,
      light: light,
      detailed: detailed,
      onVolume: (_, _, {required groundFloor}) {},
    );
    final near = _meshes(build(detailed: true)).toList();
    final far = _meshes(build(detailed: false)).toList();
    int count(List<Node> nodes, UnlitMaterial material) => nodes
        .where(
          (node) => identical(node.mesh!.primitives.single.material, material),
        )
        .length;
    expect(far.length, lessThan(near.length));
    expect(count(far, wall), count(near, wall));
    // Distant buildings use one cap at each lit crown course instead of four
    // rim pieces, preserving the height of every luminous skyline edge.
    Set<double> crownCourses(List<Node> nodes) => {
      for (final node in nodes)
        if (identical(node.mesh!.primitives.single.material, light) &&
            _bounds(node).min.y >= kit.frontageHeight)
          _bounds(node).min.y,
    };
    final courses = crownCourses(far).toList()..sort();
    final nearCourses = crownCourses(near).toList()..sort();
    expect(courses, isNotEmpty);
    expect(courses.length, nearCourses.length);
    for (var i = 0; i < courses.length; i++) {
      expect(courses[i], closeTo(nearCourses[i], 1e-5));
    }
    expect(count(far, light), courses.length);
    expect(count(far, trim), lessThan(count(near, trim)));
  });
}

Iterable<Node> _meshes(Node node) sync* {
  if (node.mesh != null) yield node;
  for (final child in node.children) {
    yield* _meshes(child);
  }
}

Aabb3 _bounds(Node node) => Aabb3.minMax(
  node.globalTransform.transform3(Vector3.all(-0.5)),
  node.globalTransform.transform3(Vector3.all(0.5)),
);
