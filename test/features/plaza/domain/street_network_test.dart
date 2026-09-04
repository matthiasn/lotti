import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/domain/street_network.dart';

import '../plaza_fixtures.dart';

double _dist((double, double) a, (double, double) b) =>
    math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));

void main() {
  // An L: 50 m east, then 50 m north.
  final corner = StreetNetwork(const [(0, 0), (50, 0), (50, 50)]);

  group('a polyline', () {
    test('drops repeated points and measures its length', () {
      final n = StreetNetwork(const [(0, 0), (0, 0.01), (50, 0), (50, 50)]);
      expect(n.vertices, hasLength(3));
      expect(n.length, closeTo(100, 1e-9));
      expect(corner.pointAt(0), (0, 0));
      expect(corner.pointAt(25), (25, 0));
      expect(corner.pointAt(75), (50, 25));
      expect(corner.pointAt(500), (50, 50));
      expect(corner.pointAt(-5), (0, 0));
    });

    test('projects a point onto its nearest stretch', () {
      final onIt = corner.project(25, 0);
      expect(onIt.along, closeTo(25, 1e-9));
      expect(onIt.offset, closeTo(0, 1e-9));
      final beside = corner.project(30, -4);
      expect(beside.along, closeTo(30, 1e-9));
      expect((beside.x, beside.z), (30, 0));
      expect(beside.offset, closeTo(4, 1e-9));
      final north = corner.project(53, 40);
      expect(north.along, closeTo(90, 1e-9));
      expect(north.offset, closeTo(3, 1e-9));
      // Before the start and past the end clamp to the ends.
      expect(corner.project(-10, 2).along, 0);
      expect(corner.project(50, 80).along, closeTo(100, 1e-9));
    });

    test('the way between two stops runs through the corner, either way', () {
      final out = corner.pathBetween((10, -3), (53, 40));
      expect(out, [(10, 0), (50, 0), (50, 40)]);
      final back = corner.pathBetween((53, 40), (10, -3));
      expect(back, out.reversed.toList());
      // A stop on the way contributes no projection: two on one stretch
      // have nothing between them, and a flight joins them directly.
      expect(corner.pathBetween((10, 0), (30, 0)), isEmpty);
      expect(corner.pathBetween((10, -3), (30, -3)), [(10, 0), (30, 0)]);
    });
  });

  group('of a street plan', () {
    final tasks = syntheticPlazaTasks();
    final plan = StreetLayout(projectSeed: 1337).plan(tasks);
    final plaza = frontierPlazaFor(plan)!;
    final network = StreetNetwork.of(plan, plaza)!;

    test('chains every segment, then the plaza mouth and home', () {
      expect(network.vertices.length, plan.segments.length + 3);
      expect(network.vertices.first, (
        plan.segments.first.startX,
        plan.segments.first.startZ,
      ));
      for (final (i, s) in plan.segments.indexed) {
        expect(network.vertices[i + 1].$1, closeTo(s.endX, 1e-9));
        expect(network.vertices[i + 1].$2, closeTo(s.endZ, 1e-9));
      }
      final mouth = network.vertices[network.vertices.length - 2];
      final sinH = math.sin(plaza.headingRadians);
      final cosH = math.cos(plaza.headingRadians);
      expect(mouth.$1, closeTo(plaza.centerX - sinH * plaza.depth / 2, 1e-9));
      expect(mouth.$2, closeTo(plaza.centerZ - cosH * plaza.depth / 2, 1e-9));
      expect(network.vertices.last, (plaza.home.x, plaza.home.z));
      // Home stands on the network: its projection is itself.
      expect(
        network.project(plaza.home.x, plaza.home.z).offset,
        lessThan(1e-9),
      );
    });

    test('a task pose reaches home down the street and up the plaza axis', () {
      final oldest = plan.placements.values.reduce(
        (a, b) => a.bucketIndex <= b.bucketIndex ? a : b,
      );
      final pose = taskPoseFor(oldest);
      final way = network.pathBetween(
        (pose.x, pose.z),
        (plaza.home.x, plaza.home.z),
      );
      // Starts at the pose's projection, ends at the mouth: home itself is
      // on the network and needs no point.
      final start = network.project(pose.x, pose.z);
      expect(way.first, (start.x, start.z));
      expect(way.last, network.vertices[network.vertices.length - 2]);
      // Every point between is a vertex, in order of the way.
      for (var i = 1; i < way.length; i++) {
        expect(network.vertices, contains(way[i]));
        expect(
          network.project(way[i].$1, way[i].$2).along,
          greaterThan(network.project(way[i - 1].$1, way[i - 1].$2).along),
        );
      }
      expect(way.length, greaterThan(3));
    });

    test('no network without a street', () {
      final empty = StreetLayout(projectSeed: 1).plan(const []);
      expect(StreetNetwork.of(empty, null), isNull);
    });
  });

  glados.Glados2<double, double>(
    glados.any.doubleInRange(-30, 90),
    glados.any.doubleInRange(-30, 90),
    glados.ExploreConfig(numRuns: 120),
  ).test('a projection lies on the polyline at its offset', (x, z) {
    final p = corner.project(x, z);
    final on = corner.pointAt(p.along);
    expect(on.$1, closeTo(p.x, 1e-6));
    expect(on.$2, closeTo(p.z, 1e-6));
    expect(_dist((x, z), (p.x, p.z)), closeTo(p.offset, 1e-6));
    // No vertex is nearer than the projection.
    for (final v in corner.vertices) {
      expect(_dist((x, z), v), greaterThanOrEqualTo(p.offset - 1e-6));
    }
  }, tags: 'glados');
}
