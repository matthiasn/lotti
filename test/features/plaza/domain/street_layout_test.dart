import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';

PlazaTask _task(String id, DateTime createdAt) {
  return PlazaTask(
    id: id,
    createdAt: createdAt,
    title: 'Task $id',
    state: PlazaTaskState.open,
    progress: 0,
    checklistItems: 0,
    linkedTaskIds: const [],
    categoryColor: 0xFF5C9DFF,
  );
}

/// A reproducible mixed-density dataset: some busy weeks, some quiet ones,
/// some empty ones.
List<PlazaTask> _dataset({int count = 60, int seed = 7}) {
  final rng = Random(seed);
  var cursor = DateTime(2026, 3, 2, 9);
  return [
    for (var i = 0; i < count; i++)
      _task(
        'task-$seed-$i',
        cursor = cursor.add(
          rng.nextDouble() < 0.6
              ? Duration(minutes: 30 + rng.nextInt(600))
              : Duration(days: 1 + rng.nextInt(12)),
        ),
      ),
  ];
}

Matcher _samePlacementAs(PlotPlacement expected) => predicate<PlotPlacement>(
  (actual) =>
      actual.taskId == expected.taskId &&
      actual.bucketIndex == expected.bucketIndex &&
      actual.side == expected.side &&
      (actual.x - expected.x).abs() < 1e-9 &&
      (actual.z - expected.z).abs() < 1e-9 &&
      (actual.facingRadians - expected.facingRadians).abs() < 1e-9 &&
      (actual.width - expected.width).abs() < 1e-9 &&
      (actual.height - expected.height).abs() < 1e-9,
  'placement identical',
);

void main() {
  final layout = StreetLayout(projectSeed: 1337);

  group('determinism', () {
    test('same input produces an identical street across runs', () {
      final tasks = _dataset();
      final a = layout.plan(tasks);
      final b = layout.plan(tasks);

      expect(b.placements.length, a.placements.length);
      for (final id in a.placements.keys) {
        expect(b.placements[id], _samePlacementAs(a.placements[id]!));
      }
      expect(b.segments.length, a.segments.length);
    });

    test('shuffled arrival order produces an identical street', () {
      // Sync delivers tasks in arbitrary order; the street must not care.
      final tasks = _dataset();
      final reference = layout.plan(tasks);
      for (final shuffleSeed in [1, 2, 3]) {
        final shuffled = [...tasks]..shuffle(Random(shuffleSeed));
        final plan = layout.plan(shuffled, epoch: reference.epoch);
        for (final id in reference.placements.keys) {
          expect(
            plan.placements[id],
            _samePlacementAs(reference.placements[id]!),
            reason: 'shuffle seed $shuffleSeed moved $id',
          );
        }
      }
    });

    test('stableHash is stable (pinned values)', () {
      // These values must never change: plot rhythm depends on them.
      expect(stableHash(''), 0x811c9dc5);
      expect(stableHash('a'), 0xe40c292c);
      expect(stableHash('plaza'), 0xd0e788b5);
    });
  });

  group('the invariant: nothing ever moves', () {
    test('appending tasks in later weeks never changes existing placements',
        () {
      final tasks = _dataset();
      final before = layout.plan(tasks);

      final lastCreated = tasks
          .map((t) => t.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final grown = [
        ...tasks,
        for (var i = 0; i < 25; i++)
          _task('new-$i', lastCreated.add(Duration(days: 7 + i * 2))),
      ];
      final after = layout.plan(grown, epoch: before.epoch);

      for (final id in before.placements.keys) {
        expect(
          after.placements[id],
          _samePlacementAs(before.placements[id]!),
          reason: 'appending later tasks moved $id',
        );
      }
      // And the street did grow.
      expect(after.segments.length, greaterThan(before.segments.length));
    });

    test(
        'a late-syncing task jostles only its own bucket — '
        'every other placement is bit-identical', () {
      final tasks = _dataset();
      final before = layout.plan(tasks);

      // Drop a new task into the middle of an existing busy week.
      final targetBucketTask = tasks[tasks.length ~/ 2];
      final lateTask = _task(
        'late-syncer',
        targetBucketTask.createdAt.add(const Duration(hours: 1)),
      );
      final after = layout.plan([...tasks, lateTask], epoch: before.epoch);

      final touchedBucket = after.placements['late-syncer']!.bucketIndex;
      expect(
        touchedBucket,
        before.placements[targetBucketTask.id]!.bucketIndex,
      );

      for (final id in before.placements.keys) {
        final b = before.placements[id]!;
        if (b.bucketIndex == touchedBucket) {
          // Same plot group is the only permitted blast radius; the task
          // must stay in its bucket even if it slides within it.
          expect(after.placements[id]!.bucketIndex, touchedBucket);
        } else {
          expect(
            after.placements[id],
            _samePlacementAs(b),
            reason: 'late syncer in bucket $touchedBucket moved $id '
                'in bucket ${b.bucketIndex}',
          );
        }
      }

      // The road itself is untouched: same segments, same bends.
      expect(after.segments.length, before.segments.length);
      for (var i = 0; i < before.segments.length; i++) {
        expect(after.segments[i].startX, before.segments[i].startX);
        expect(after.segments[i].startZ, before.segments[i].startZ);
        expect(
          after.segments[i].headingRadians,
          before.segments[i].headingRadians,
        );
      }
    });
  });

  group('street structure', () {
    test('empty weeks collapse to gap segments, busy weeks to plot groups',
        () {
      final tasks = [
        _task('w0-a', DateTime(2026, 3, 2, 10)),
        _task('w0-b', DateTime(2026, 3, 3, 10)),
        // Weeks 1 and 2 empty.
        _task('w3-a', DateTime(2026, 3, 24, 10)),
      ];
      final plan = layout.plan(tasks);

      expect(plan.segments.map((s) => s.isGap), [false, true, true, false]);
      expect(plan.segments[1].length, layout.gapLength);
      expect(plan.segments[0].length, layout.groupLength);
      expect(plan.placements['w0-a']!.bucketIndex, 0);
      expect(plan.placements['w3-a']!.bucketIndex, 3);
    });

    test('within a week, tasks alternate sides in (createdAt, id) order', () {
      final base = DateTime(2026, 3, 2, 9);
      final tasks = [
        for (var i = 0; i < 5; i++)
          _task('t$i', base.add(Duration(hours: i))),
      ];
      final plan = layout.plan(tasks);

      expect(plan.placements['t0']!.side, PlotSide.left);
      expect(plan.placements['t1']!.side, PlotSide.right);
      expect(plan.placements['t2']!.side, PlotSide.left);
      expect(plan.placements['t3']!.side, PlotSide.right);
      expect(plan.placements['t4']!.side, PlotSide.left);
    });

    test('building widths stay within bounds however busy the week', () {
      final base = DateTime(2026, 3, 2, 9);
      final crowded = [
        for (var i = 0; i < 40; i++)
          _task('busy-$i', base.add(Duration(minutes: i))),
      ];
      final plan = layout.plan(crowded);
      for (final placement in plan.placements.values) {
        expect(
          placement.width,
          inInclusiveRange(layout.minBuildingWidth, layout.maxBuildingWidth),
        );
      }
    });

    test('weekStart anchors to Monday 00:00', () {
      expect(
        StreetLayout.weekStart(DateTime(2026, 9, 3, 15, 30)), // A Thursday.
        DateTime(2026, 8, 31), // The preceding Monday.
      );
      expect(
        StreetLayout.weekStart(DateTime(2026, 8, 31, 0, 1)), // A Monday.
        DateTime(2026, 8, 31),
      );
    });
  });
}
