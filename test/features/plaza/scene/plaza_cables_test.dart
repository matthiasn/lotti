import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/plaza/domain/cable_path.dart';
import 'package:lotti/features/plaza/domain/plaza_connection.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_cables.dart';
import 'package:lotti/features/plaza/scene/plaza_static_meshes.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:vector_math/vector_math.dart';

import '../plaza_fixtures.dart';

List<CablePath> _paths(EntryLinkType type) {
  final tasks = syntheticPlazaTasks(
    count: 12,
  ).where((t) => !t.deleted).take(6).toList();
  return PlazaWorld(
    tasks: tasks,
    now: syntheticNow(tasks),
    projectLabel: 'Fixture',
    layout: StreetLayout(projectSeed: 1),
    connections: [
      for (var i = 0; i < 3; i++)
        PlazaConnection(
          id: '$i',
          fromId: tasks[i * 2].id,
          toId: tasks[i * 2 + 1].id,
          type: type,
        ),
    ],
  ).cablePaths;
}

void main() {
  const stride = BillboardGeometry.floatsPerInstance;
  test('selection creates only incident overlays and reuses them', () {
    final paths = _paths(EntryLinkType.blocks);
    final root = Node();
    final created = <CablePath>[];
    final selection = PlazaCableSelection(
      paths: paths,
      root: root,
      create: (path) {
        created.add(path);
        return Node()..raycastable = false;
      },
    )..update(null);
    expect(created, isEmpty);
    selection.update(paths.first.connection.fromId);
    expect(created, [paths.first]);
    final first = root.children.single;
    expect(first.visible, isTrue);
    selection.update(paths.last.connection.toId);
    expect(created, [paths.first, paths.last]);
    expect(first.visible, isFalse);
    expect(root.children.last.visible, isTrue);
    selection
      ..update(paths.first.connection.fromId)
      ..update(paths.first.connection.fromId);
    expect(created, [paths.first, paths.last]);
    expect(first.visible, isTrue);
    expect(root.children.last.visible, isFalse);
    selection.update(null);
    expect(root.children.every((n) => !n.visible), isTrue);
  });

  test('repeated connections share a roof mast at the highest attachment', () {
    final tasks = syntheticPlazaTasks(
      count: 12,
    ).where((t) => !t.deleted).take(4).toList();
    final world = PlazaWorld(
      tasks: tasks,
      now: syntheticNow(tasks),
      projectLabel: 'Fixture',
      layout: StreetLayout(projectSeed: 1),
      cables: const CableConfig(maxSupports: 0),
      connections: [
        for (final task in tasks.skip(1))
          PlazaConnection(
            id: task.id,
            fromId: tasks.first.id,
            toId: task.id,
            type: EntryLinkType.blocks,
          ),
      ],
    );
    final mounts = cableSupportsFor(world.cablePaths);
    expect(mounts, hasLength(tasks.length));
    final origin = world.cablePaths.first.supports.first;
    final mast = mounts.singleWhere((m) => m.x == origin.x && m.z == origin.z);
    for (final path in world.cablePaths) {
      expect(path.supports.first.x, origin.x);
      expect(path.supports.first.z, origin.z);
      expect(mast.y, greaterThanOrEqualTo(path.supports.first.y));
    }
    expect(mounts.clear, throwsUnsupportedError);
  });

  test(
    'tube encloses the path with outward triangles and bounded vertices',
    () {
      final path = _paths(EntryLinkType.blocks).first;
      final mesh = cableTubeMesh(path, 0.2, origin: Vector3.zero());
      expect(mesh.vertexCount, path.distances.length * 6);
      expect(mesh.triangleCount, (path.distances.length - 1) * 12);
      for (var ring = 0; ring < path.distances.length; ring++) {
        final center = Vector3.array(path.positions, ring * 3);
        for (var side = 0; side < 6; side++) {
          final p = Vector3.array(mesh.positions, (ring * 6 + side) * 3);
          expect(p.distanceTo(center), closeTo(0.2, 1e-5));
        }
      }
      for (final triangle in mesh.triangles) {
        final normal = (triangle.pb - triangle.pa).cross(
          triangle.pc - triangle.pa,
        );
        final center = Vector3.array(path.positions, (triangle.a ~/ 6) * 3);
        expect(normal.dot(triangle.pa - center), greaterThan(0));
      }
    },
  );

  test('tube batches retain spatial cells and exact world placement', () {
    final paths = _paths(EntryLinkType.blocks);
    final meshes = <Geometry, MeshData>{};
    Geometry upload(MeshData mesh) {
      final geometry = UnskinnedGeometry();
      meshes[geometry] = mesh;
      return geometry;
    }

    final root = Node();
    final material = UnlitMaterial();
    for (final path in paths) {
      final expected = cableTubeMesh(path, 0.2, origin: Vector3.zero());
      for (var copy = 0; copy < 2; copy++) {
        final node = cableTubeNode(path, 0.2, material, upload: upload);
        root.add(node);
        final actual = meshes[node.mesh!.primitives.single.geometry]!
            .transformed(node.globalTransform);
        for (var i = 0; i < expected.positions.length; i++) {
          expect(actual.positions[i], closeTo(expected.positions[i], 1e-4));
        }
        expect(node.raycastable, isFalse);
      }
    }
    final batches = PlazaStaticMeshes(
      cellSize: 1,
      read: (geometry) => meshes[geometry]!,
      upload: upload,
    ).bake(root, preserve: {});
    expect(batches, (meshes: 6, batches: 3));
    expect(
      root.children.map(
        (n) => meshes[n.mesh!.primitives.single.geometry]!.vertexCount,
      ),
      unorderedEquals([
        for (final path in paths) path.distances.length * 6 * 2,
      ]),
      reason: 'each spatial cell contains only its own pair of cable meshes',
    );
  });

  for (final type in [EntryLinkType.basic, EntryLinkType.blocks]) {
    test(
      '$type packets follow arc distance and preserve relation direction',
      () {
        final path = _paths(type).first;
        final data = Float32List(stride * 2);
        final buffer = PlazaCableBuffer(paths: [path], data: data);
        final eye = Vector3.array(path.positions);
        buffer.update(0, eye);
        final phase = stableUnit(path.connection.id, 'light');
        buffer.update(0.1, eye);
        final expected = Float64List(3);
        for (var packet = 0; packet < 2; packet++) {
          var fraction = (phase + packet / 2 + 1.2 / path.length) % 1;
          if (type == EntryLinkType.basic && packet == 1) {
            fraction = 1 - fraction;
          }
          path.writePosition(fraction * path.length, expected, 0);
          for (var axis = 0; axis < 3; axis++) {
            expect(data[packet * stride + axis], closeTo(expected[axis], 1e-5));
          }
        }
        expect(buffer.data, same(data));
        expect(buffer.hasVisibleMotion, isTrue);
        final frozen = data.toList();
        buffer.update(3, eye, animate: false);
        expect(buffer.hasVisibleMotion, isFalse);
        expect(data, frozen);
        buffer.update(3.1, eye);
        expect(data, isNot(frozen));
      },
    );
  }

  test('selection outranks distance within a fixed instance budget', () {
    final paths = _paths(EntryLinkType.blocks);
    final data = Float32List(stride * 2);
    final buffer = PlazaCableBuffer(paths: paths, data: data, maxCables: 1);
    final first = paths.first;
    final eye = Vector3.array(
      first.positions,
      (first.positions.length ~/ 6) * 3,
    );
    buffer.update(0, eye);
    final nearby = data.toList();
    buffer.update(0, eye, focusedTask: paths.last.connection.toId);
    expect(buffer.count, 2);
    expect(data, isNot(nearby));
    expect(data[3], 3);
    final expected = Float64List(3);
    paths.last.writePosition(
      stableUnit(paths.last.connection.id, 'light') * paths.last.length,
      expected,
      0,
    );
    expect(data[0], closeTo(expected[0], 1e-5));
    expect(data[1], closeTo(expected[1], 1e-5));
    buffer.update(1, Vector3.all(10000));
    expect(buffer.hasVisibleMotion, isFalse);
    expect(data[9], 0);
    expect(data[stride + 9], 0);
  });

  test(
    'bounds include all routes even when the animated budget is smaller',
    () {
      final paths = _paths(EntryLinkType.basic);
      final data = Float32List(stride * 2);
      final buffer = PlazaCableBuffer(paths: paths, data: data, maxCables: 1);
      var committed = -1;
      buffer.reserveBounds((count) {
        committed = count;
        for (final path in paths) {
          for (var i = 0; i < path.positions.length; i += 3) {
            for (var axis = 0; axis < 3; axis++) {
              expect(
                path.positions[i + axis],
                inInclusiveRange(data[axis], data[stride + axis]),
              );
            }
          }
        }
      });
      expect(committed, 2);
      expect(data, everyElement(0));
    },
  );

  test(
    'empty or disabled light budgets draw nothing; short storage rejects',
    () {
      for (final paths in [<CablePath>[], _paths(EntryLinkType.basic)]) {
        final buffer = PlazaCableBuffer(
          paths: paths,
          data: Float32List(0),
          maxCables: 0,
        );
        var committed = -1;
        buffer
          ..reserveBounds((count) => committed = count)
          ..update(0, Vector3.zero());
        expect(committed, 0);
        expect(buffer.hasVisibleMotion, isFalse);
      }
      expect(
        () => PlazaCableBuffer(
          paths: _paths(EntryLinkType.basic),
          data: Float32List(0),
        ),
        throwsArgumentError,
      );
    },
  );
}
