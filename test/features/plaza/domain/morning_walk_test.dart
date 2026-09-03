import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/morning_walk.dart';
import 'package:lotti/features/plaza/domain/plaza_generator.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

void main() {
  final tasks = generatePlazaTasks(preset: PlazaPreset.medium);
  final plan = StreetLayout(projectSeed: 1337).plan(tasks);
  final plaza = frontierPlazaFor(plan)!;
  final anomalyList = anomalies(attentionForAll(tasks, plazaNowFor(tasks)));

  test('stops: overview, up to three anomalies, home', () {
    final stops = morningWalkStops(plan, plaza, anomalyList, projectLabel: 'P');
    expect(anomalyList.length, greaterThanOrEqualTo(3));
    expect(stops, hasLength(5));
    expect(stops.first.pose, plaza.overview);
    expect(stops.first.hold, const Duration(seconds: 4));
    expect(stops.first.label, 'Overview — P');
    for (var i = 1; i <= 3; i++) {
      expect(
        stops[i].pose.x,
        taskPoseFor(plan.placements[anomalyList[i - 1].task.id]!).x,
      );
      expect(stops[i].label, anomalyList[i - 1].task.title);
      expect(stops[i].hold, const Duration(milliseconds: 3200));
    }
    expect(stops.last.pose, plaza.home);
  });

  test('a quiet project still walks overview → home', () {
    final stops = morningWalkStops(plan, plaza, const [], projectLabel: 'P');
    expect(stops.map((s) => s.label), ['Overview — P', 'Home — P']);
  });

  test('holds each stop, advances on time, pauses, finishes', () {
    final stops = morningWalkStops(plan, plaza, anomalyList, projectLabel: 'P');
    final walk = MorningWalk(stops);
    expect(walk.index, 0);
    expect(walk.chip, contains('stop 1 of 5'));
    // Not holding until the flight lands.
    expect(walk.tick(const Duration(seconds: 10)), isNull);
    walk.arrived();
    expect(walk.tick(const Duration(seconds: 3)), isNull);
    final next = walk.tick(const Duration(seconds: 1))!;
    expect(next, stops[1]);
    expect(walk.index, 1);

    walk
      ..arrived()
      ..togglePause();
    expect(walk.chip, contains('space to resume'));
    expect(walk.tick(const Duration(seconds: 30)), isNull); // paused
    walk.togglePause();
    expect(walk.tick(const Duration(milliseconds: 3200)), stops[2]);

    for (var i = 2; i < stops.length - 1; i++) {
      walk.arrived();
      expect(walk.tick(const Duration(seconds: 10)), stops[i + 1]);
    }
    expect(walk.index, stops.length - 1);
    walk.arrived();
    expect(walk.tick(const Duration(seconds: 1)), isNull);
    expect(walk.finished, isTrue);
  });

  test('any movement abandons the walk', () {
    final walk =
        MorningWalk(
            morningWalkStops(plan, plaza, anomalyList, projectLabel: 'P'),
          )
          ..arrived()
          ..abandon();
    expect(walk.finished, isTrue);
    expect(walk.tick(const Duration(seconds: 30)), isNull);
  });
}
