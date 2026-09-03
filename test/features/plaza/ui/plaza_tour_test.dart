import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_generator.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_tour.dart';

PlazaWorld _world(PlazaPreset preset) {
  final tasks = generatePlazaTasks(preset: preset);
  return PlazaWorld(
    tasks: tasks,
    now: plazaNowFor(tasks),
    projectLabel: 'Test',
    layout: StreetLayout(projectSeed: 1337),
  );
}

void main() {
  final large = _world(PlazaPreset.large);
  final small = _world(PlazaPreset.small);

  test('names are unique and usable as file names', () {
    final names = plazaTourStops.map((s) => s.name).toList();
    expect(names.toSet().length, names.length);
    for (final name in names) {
      expect(RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(name), isTrue, reason: name);
    }
  });

  test('covers both datasets and the poses that matter', () {
    expect(
      plazaTourStops.map((s) => s.preset).toSet(),
      TourPreset.values.toSet(),
    );
    expect(plazaTourStops.map((s) => s.name), containsAll(['home', 'overview', 'billboard']));
  });

  test('every stop resolves on a district with anomalies and folds', () {
    for (final stop in plazaTourStops) {
      final pose = stop.pose(large);
      expect(pose, isNotNull, reason: stop.name);
      expect(pose!.x.isFinite && pose.z.isFinite && pose.yaw.isFinite, isTrue);
    }
    expect(
      plazaTourStops.firstWhere((s) => s.name == 'home').pose(large),
      large.plaza!.home,
    );
    expect(
      plazaTourStops.firstWhere((s) => s.name == 'overview').pose(large),
      large.plaza!.overview,
    );
  });

  test('a street too short to fold has no corner stop', () {
    expect(
      plazaTourStops.firstWhere((s) => s.name == 'district-corner').pose(small),
      isNull,
    );
  });

  test('is a pure function of the world', () {
    final again = _world(PlazaPreset.large);
    for (final stop in plazaTourStops) {
      final a = stop.pose(large)!;
      final b = stop.pose(again)!;
      expect(a.x, b.x, reason: stop.name);
      expect(a.z, b.z);
      expect(a.yaw, b.yaw);
      expect(a.pitch, b.pitch);
    }
  });

  test('blockBeaconPose walks oldest to newest and clamps', () {
    final blocks = large.beacons.where((b) => b.kind == BeaconKind.block).toList();
    final oldest = blocks.last.pose; // beacons list newest first
    expect(blockBeaconPose(large, fraction: 0)!.x, oldest.x);
    expect(blockBeaconPose(large, fraction: 5)!.x, blocks.first.pose.x);
    final empty = PlazaWorld(
      tasks: const [],
      now: DateTime.utc(2026),
      projectLabel: 'Empty',
      layout: StreetLayout(projectSeed: 1),
    );
    expect(blockBeaconPose(empty, fraction: 0.5), isNull);
  });
}
