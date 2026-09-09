import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/plaza/domain/building_architecture.dart';
import 'package:lotti/features/plaza/domain/cable_path.dart';
import 'package:lotti/features/plaza/domain/plaza_connection.dart';
import 'package:lotti/features/plaza/domain/solid.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

PlotPlacement _plot(String id, double x, {double height = 20}) => PlotPlacement(
  taskId: id,
  bucketIndex: 0,
  side: PlotSide.left,
  x: x,
  z: 0,
  facingRadians: 0,
  width: 12,
  depth: 10,
  height: height,
);

CablePath _path({
  List<Solid> solids = const [],
  CableConfig config = const CableConfig(),
  double toHeight = 20,
}) {
  final from = _plot('a', -50);
  final to = _plot('b', 50, height: toHeight);
  return CablePath.plan(
    connection: const PlazaConnection(
      id: 'a-blocks-b',
      fromId: 'a',
      toId: 'b',
      type: EntryLinkType.blocks,
    ),
    from: from,
    to: to,
    fromArchitecture: BuildingArchitecture.forPlot(from),
    toArchitecture: BuildingArchitecture.forPlot(to),
    solids: solids,
    config: config,
  );
}

void main() {
  test('roof mounts frame a sagging span in relationship direction', () {
    final cable = _path();
    expect(cable.supports, hasLength(2));
    final a = cable.supports.first;
    final b = cable.supports.last;
    expect(a.x, lessThan(b.x));
    expect(a.baseY, 20);
    expect(b.baseY, 20);
    expect(a.y, 23);
    expect(b.y, 23);
    expect(cable.positions[12 * 3 + 1], closeTo(15, 1e-9));
    expect(cable.length, greaterThan(b.x - a.x));
    expect(cable.supports.clear, throwsUnsupportedError);
  });

  test(
    'arc sampling interpolates and clamps without touching other fields',
    () {
      final path = _path(toHeight: 60);
      final output = Float32List(8)..fillRange(0, 8, -1);
      for (final i in [0, 6, 23, 24]) {
        path.writePosition(path.distances[i], output, 2);
        for (var axis = 0; axis < 3; axis++) {
          expect(output[2 + axis], closeTo(path.positions[i * 3 + axis], 1e-5));
        }
      }
      final halfway = (path.distances[6] + path.distances[7]) / 2;
      path.writePosition(halfway, output, 2);
      for (var axis = 0; axis < 3; axis++) {
        expect(
          output[2 + axis],
          closeTo(
            (path.positions[18 + axis] + path.positions[21 + axis]) / 2,
            1e-5,
          ),
        );
      }
      path.writePosition(-100, output, 2);
      expect(output[2], closeTo(path.supports.first.x, 1e-5));
      path.writePosition(path.length + 100, output, 2);
      expect(output[2], closeTo(path.supports.last.x, 1e-5));
      expect([output[0], output[1], ...output.skip(5)], everyElement(-1));
      for (var i = 1; i < path.distances.length; i++) {
        expect(path.distances[i], greaterThan(path.distances[i - 1]));
      }
    },
  );

  for (final angle in [0.0, math.pi / 4, math.pi / 2]) {
    test('clears a thin rotated tower between samples at $angle', () {
      const config = CableConfig(samplesPerSpan: 4, maxSupports: 0);
      final obstacle = Solid(
        footprint: Footprint(
          x: 11,
          z: 0,
          facingRadians: angle,
          width: 0.05,
          depth: 20,
        ),
        top: 80,
      );
      final path = _path(solids: [obstacle], config: config);
      final point = Float64List(3);
      var checked = 0;
      for (var i = 0; i <= 10000; i++) {
        path.writePosition(path.length * i / 10000, point, 0);
        if (obstacle.footprint.contains(
          point[0],
          point[2],
          clearance: config.clearance + config.radius,
        )) {
          checked++;
          expect(
            point[1],
            greaterThanOrEqualTo(
              obstacle.top + config.clearance + config.radius - 1e-9,
            ),
          );
        }
      }
      expect(checked, greaterThan(0));
      expect(path.supports, hasLength(2));
    });
  }

  test('intermediate supports clear obstacles with a bounded stable route', () {
    const config = CableConfig(maxSupports: 3);
    final solids = [
      for (var i = -3; i <= 3; i++)
        Solid.post(x: i * 10, z: 0, size: 4, top: 40 + i * 2),
      Solid.post(x: 0, z: 80, size: 4, top: 500),
    ];
    final a = _path(solids: solids, config: config);
    final b = _path(
      solids: solids.reversed.toList(),
      config: config,
    );
    expect(a.supports, hasLength(5));
    for (var i = 0; i < a.positions.length; i++) {
      expect(a.positions[i], closeTo(b.positions[i], 1e-9));
    }
    expect(a.supports.map((s) => s.y), everyElement(lessThan(100)));
    final point = Float64List(3);
    for (var i = 0; i <= 2000; i++) {
      a.writePosition(a.length * i / 2000, point, 0);
      expect(
        solids.any(
          (s) => s.contains(
            point[0],
            point[1],
            point[2],
            clearance: config.clearance + config.radius - 1e-8,
          ),
        ),
        isFalse,
      );
    }
  });

  test('zero sag produces straight geometry', () {
    final path = _path(config: const CableConfig(sagRatio: 0));
    final a = path.supports.first;
    final b = path.supports.last;
    expect(
      path.length,
      closeTo(
        math.sqrt(
          math.pow(b.x - a.x, 2) + math.pow(b.z - a.z, 2),
        ),
        1e-9,
      ),
    );
    for (var i = 1; i < path.positions.length; i += 3) {
      expect(path.positions[i], a.y);
    }
  });
}
