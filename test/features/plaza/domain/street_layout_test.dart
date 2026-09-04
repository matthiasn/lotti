import 'dart:math' as math;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
  var cursor = DateTime.utc(2026, 3, 2, 9);
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

int _segmentIndexOf(StreetPlan plan, int bucketIndex) => plan.segments
    .indexWhere((s) => s.bucketIndex == bucketIndex && !s.isConnector);

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
  group('stableUnit', () {
    test('is deterministic, in 0..1, and salt-sensitive', () {
      expect(stableUnit('a', 'w'), stableUnit('a', 'w'));
      expect(stableUnit('a', 'w'), isNot(stableUnit('a', 'h')));
      expect(stableUnit('a', 'w'), isNot(stableUnit('b', 'w')));
      for (var i = 0; i < 200; i++) {
        expect(stableUnit('id-$i', 's'), inInclusiveRange(0, 1));
      }
      // The exact value is part of the contract: a plot's massing and
      // every seeded block would move if the hash changed.
      expect(
        stableUnit('a', 'w'),
        (stableHash('a:w') & 0xFFFF) / 0xFFFF,
      );
    });
  });

  test('PlotPlacement.footprint is the plot rectangle', () {
    const p = PlotPlacement(
      taskId: 't',
      bucketIndex: 2,
      side: PlotSide.right,
      x: 3,
      z: -4,
      facingRadians: 1.2,
      width: 9,
      depth: 8,
      height: 20,
    );
    final f = p.footprint;
    expect(f.x, 3);
    expect(f.z, -4);
    expect(f.facingRadians, 1.2);
    expect(f.width, 9);
    expect(f.depth, 8);
  });

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
    test(
      'appending tasks in later weeks never changes existing placements',
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
      },
    );

    test('a late-syncing task jostles only its own bucket — '
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
            reason:
                'late syncer in bucket $touchedBucket moved $id '
                'in bucket ${b.bucketIndex}',
          );
        }
      }

      // The road itself is untouched: same segments, same folds.
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
    test('empty weeks collapse to gap segments, busy weeks to plot groups', () {
      final tasks = [
        _task('w0-a', DateTime.utc(2026, 3, 2, 10)),
        _task('w0-b', DateTime.utc(2026, 3, 3, 10)),
        // Weeks 1 and 2 empty.
        _task('w3-a', DateTime.utc(2026, 3, 24, 10)),
      ];
      final plan = layout.plan(tasks);

      expect(plan.segments.map((s) => s.isGap), [false, true, true, false]);
      expect(plan.segments[1].length, layout.gapLength);
      expect(plan.segments[0].length, layout.groupLength);
      expect(plan.placements['w0-a']!.bucketIndex, 0);
      expect(plan.placements['w3-a']!.bucketIndex, 3);
    });

    test('within a week, tasks alternate sides in (createdAt, id) order', () {
      final base = DateTime.utc(2026, 3, 2, 9);
      final tasks = [
        for (var i = 0; i < 5; i++) _task('t$i', base.add(Duration(hours: i))),
      ];
      final plan = layout.plan(tasks);

      expect(plan.placements['t0']!.side, PlotSide.left);
      expect(plan.placements['t1']!.side, PlotSide.right);
      expect(plan.placements['t2']!.side, PlotSide.left);
      expect(plan.placements['t3']!.side, PlotSide.right);
      expect(plan.placements['t4']!.side, PlotSide.left);
    });

    test('crowded weeks never overlap neighboring buildings', () {
      final base = DateTime.utc(2026, 3, 2, 9);
      final crowded = [
        for (var i = 0; i < 40; i++)
          _task('busy-$i', base.add(Duration(minutes: i))),
      ];
      final plan = layout.plan(crowded);
      for (final placement in plan.placements.values) {
        expect(placement.width, lessThanOrEqualTo(layout.maxBuildingWidth));
        expect(placement.width, greaterThan(0));
      }
      // Same bucket, same side: neighbors must not intersect along the road.
      for (final side in PlotSide.values) {
        final sidePlacements =
            plan.placements.values
                .where((p) => p.side == side && p.bucketIndex == 0)
                .toList()
              ..sort((a, b) => a.z.compareTo(b.z));
        for (var i = 1; i < sidePlacements.length; i++) {
          final a = sidePlacements[i - 1];
          final b = sidePlacements[i];
          final centerGap = (b.z - a.z).abs();
          expect(
            centerGap + 1e-9,
            greaterThanOrEqualTo((a.width + b.width) / 2),
            reason: 'buildings ${a.taskId} and ${b.taskId} overlap',
          );
        }
      }
    });

    test('a task older than an explicit epoch lands in bucket zero', () {
      final tasks = [
        _task('anchor', DateTime.utc(2026, 3, 9, 10)),
        _task('straggler', DateTime.utc(2026, 2, 2, 10)),
      ];
      final plan = layout.plan(
        tasks,
        epoch: StreetLayout.weekStart(DateTime.utc(2026, 3, 9)),
      );
      expect(plan.placements['straggler']!.bucketIndex, 0);
      expect(plan.placements['anchor']!.bucketIndex, 0);
    });

    test('an empty project plans an empty street', () {
      final plan = layout.plan([]);
      expect(plan.segments, isEmpty);
      expect(plan.placements, isEmpty);
    });

    test('height is weight: links and open items add height, words do not', () {
      final bare = _task('t', DateTime.utc(2026, 3, 2, 9));
      PlazaTask variant({
        String title = 'Task t',
        int priority = 2,
        List<String> links = const [],
        List<String> open = const [],
      }) => PlazaTask(
        id: 't',
        createdAt: bare.createdAt,
        title: title,
        state: bare.state,
        progress: 0,
        checklistItems: open.length,
        openChecklistItems: open,
        linkedTaskIds: links,
        categoryColor: 0xFF5C9DFF,
        priority: priority,
      );
      final plain = layout.heightFor(bare);
      expect(plain, layout.minBuildingHeight);
      // A long title changes nothing.
      expect(layout.heightFor(variant(title: 'x' * 400)), plain);
      // Heft adds height, urgency multiplies it, the cap holds.
      final heavy = layout.heightFor(
        variant(links: const ['a', 'b', 'c'], open: const ['1', '2']),
      );
      expect(heavy, greaterThan(plain));
      final urgent = layout.heightFor(
        variant(
          priority: 0,
          links: const ['a', 'b', 'c'],
          open: const ['1', '2'],
        ),
      );
      expect(urgent, greaterThan(heavy));
      final low = layout.heightFor(
        variant(
          priority: 3,
          links: const ['a', 'b', 'c'],
          open: const ['1', '2'],
        ),
      );
      expect(low, lessThan(heavy));
      final tower = layout.heightFor(
        variant(
          priority: 0,
          links: List.filled(40, 'l'),
          open: List.filled(8, 'o'),
        ),
      );
      expect(tower, layout.maxBuildingHeight);
    });

    test('weekStart anchors to Monday 00:00 UTC', () {
      expect(
        StreetLayout.weekStart(DateTime.utc(2026, 9, 3, 15, 30)), // Thursday.
        DateTime.utc(2026, 8, 31), // The preceding Monday.
      );
      expect(
        StreetLayout.weekStart(DateTime.utc(2026, 8, 31, 0, 1)), // Monday.
        DateTime.utc(2026, 8, 31),
      );
      // A local time converts to the same UTC week as its instant.
      expect(
        StreetLayout.weekStart(DateTime.utc(2026, 9, 3, 12).toLocal()),
        DateTime.utc(2026, 8, 31),
      );
    });
  });

  group('the fold', () {
    test('turns 90° after every foldEvery buckets, alternating sides', () {
      final folded = StreetLayout(projectSeed: 1, foldEvery: 3);
      expect(folded.foldAfter(0), 0);
      expect(folded.foldAfter(1), 0);
      expect(folded.foldAfter(2), closeTo(-pi / 2, 1e-12));
      expect(folded.foldAfter(5), closeTo(pi / 2, 1e-12));
      expect(folded.foldAfter(8), closeTo(-pi / 2, 1e-12));
    });

    test('rows run in alternating directions joined by connectors', () {
      final folded = StreetLayout(projectSeed: 1, foldEvery: 3);
      // Twelve consecutive built weeks → four rows.
      final tasks = [
        for (var w = 0; w < 12; w++)
          _task('w$w', DateTime.utc(2026, 3, 2, 9).add(Duration(days: 7 * w))),
      ];
      final plan = folded.plan(tasks);
      final connectors = plan.segments.where((s) => s.isConnector).toList();
      expect(connectors, hasLength(3));
      for (final c in connectors) {
        expect(c.length, folded.connectorLength);
        expect(c.isGap, isTrue);
      }
      // Row headings: 0, π, 0, π (mod 2π).
      final rows = plan.segments.where((s) => !s.isConnector).toList();
      double norm(double a) => ((a % (2 * pi)) + 2 * pi) % (2 * pi);
      for (var i = 0; i < rows.length; i++) {
        final expected = (i ~/ 3).isEven ? 0.0 : pi;
        expect(
          norm(rows[i].headingRadians),
          closeTo(expected, 1e-9),
          reason: 'row segment $i',
        );
      }
      // The connector sits at the end of a row and is perpendicular to it.
      expect(
        norm(connectors.first.headingRadians),
        closeTo(norm(rows[2].headingRadians - pi / 2), 1e-9),
      );
      // Rows are separated by the connector length, so plots never overlap
      // across rows.
      final row0z = rows[0].startZ;
      final row1z = rows[3].startZ;
      expect((row1z - row0z).abs(), closeTo(rows[0].length * 3, 1e-9));
      expect(
        (rows[3].startX - rows[0].startX).abs(),
        closeTo(folded.connectorLength, 1e-9),
      );
      // Every connector carries no buildings.
      for (final p in plan.placements.values) {
        expect(
          plan.segments[_segmentIndexOf(plan, p.bucketIndex)].isConnector,
          isFalse,
        );
      }
    });

    test('the fold is a function of the bucket index, not of the tasks', () {
      final folded = StreetLayout(projectSeed: 1, foldEvery: 3);
      final base = [
        for (var w = 0; w < 8; w++)
          _task('w$w', DateTime.utc(2026, 3, 2, 9).add(Duration(days: 7 * w))),
      ];
      final before = folded.plan(base);
      final grown = [
        ...base,
        for (var i = 0; i < 9; i++)
          _task(
            'extra$i',
            DateTime.utc(
              2026,
              3,
              3,
              9,
            ).add(Duration(days: 7 * (i % 8), hours: i)),
          ),
      ];
      final after = folded.plan(grown, epoch: before.epoch);
      expect(after.segments.length, before.segments.length);
      for (var i = 0; i < before.segments.length; i++) {
        expect(
          after.segments[i].headingRadians,
          before.segments[i].headingRadians,
        );
        expect(after.segments[i].isConnector, before.segments[i].isConnector);
      }
    });

    test('a street shorter than one row never folds', () {
      final plan = layout.plan(_dataset(count: 8));
      expect(plan.segments.where((s) => s.isConnector), isEmpty);
    });
  });

  group('footprintsOverlap', () {
    const a = Footprint(x: 0, z: 0, facingRadians: 0, width: 10, depth: 4);

    test('boxes that share ground overlap; boxes apart or touching do not', () {
      expect(footprintsOverlap(a, a), isTrue);
      const beside = Footprint(
        x: 10,
        z: 0,
        facingRadians: 0,
        width: 10,
        depth: 4,
      );
      expect(footprintsOverlap(a, beside), isFalse); // edges touch at x = 5
      const near = Footprint(
        x: 9.9,
        z: 0,
        facingRadians: 0,
        width: 10,
        depth: 4,
      );
      expect(footprintsOverlap(a, near), isTrue);
      const behind = Footprint(
        x: 0,
        z: 4.5,
        facingRadians: 0,
        width: 10,
        depth: 4,
      );
      expect(footprintsOverlap(a, behind), isFalse);
      // Turned a quarter: the 10 m width now runs along Z and reaches a.
      const turned = Footprint(
        x: 0,
        z: 6,
        facingRadians: math.pi / 2,
        width: 10,
        depth: 2,
      );
      expect(footprintsOverlap(a, turned), isTrue);
      const turnedAway = Footprint(
        x: 0,
        z: 8,
        facingRadians: math.pi / 2,
        width: 10,
        depth: 2,
      );
      expect(footprintsOverlap(a, turnedAway), isFalse);
      // A diamond whose corner reaches in where an axis-aligned box's would not.
      const diamond = Footprint(
        x: 5 + 2.5,
        z: 0,
        facingRadians: math.pi / 4,
        width: 4,
        depth: 4,
      );
      expect(footprintsOverlap(a, diamond), isTrue);
    });

    glados.Glados3<double, double, double>(
      glados.any.doubleInRange(-30, 30),
      glados.any.doubleInRange(-30, 30),
      glados.any.doubleInRange(-math.pi, math.pi),
      glados.ExploreConfig(numRuns: 120),
    ).test('is symmetric, and agrees with the point test on the centres', (
      x,
      z,
      facing,
    ) {
      final b = Footprint(
        x: x,
        z: z,
        facingRadians: facing,
        width: 6,
        depth: 3,
      );
      expect(footprintsOverlap(a, b), footprintsOverlap(b, a));
      // A box whose centre is inside the other overlaps it; far apart, never.
      final (u, v) = a.local(x, z);
      if (u.abs() < 5 && v.abs() < 2) expect(footprintsOverlap(a, b), isTrue);
      if (x.abs() > 5 + 3.5 || z.abs() > 2 + 3.5) {
        expect(footprintsOverlap(a, b), isFalse, reason: '$x $z $facing');
      }
    }, tags: 'glados');
  });
}
