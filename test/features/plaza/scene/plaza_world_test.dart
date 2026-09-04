import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

import '../plaza_fixtures.dart';

void main() {
  final tasks = syntheticPlazaTasks();
  final world = PlazaWorld(
    tasks: tasks,
    now: syntheticNow(tasks),
    projectLabel: 'Synthetic',
    layout: StreetLayout(projectSeed: 1337),
    categoryLabels: {0xFF5C9DFF.toRadixString(16): 'work'},
  );

  test('derives plan, plaza, attention, beacons and billboards once', () {
    expect(world.plan.placements.length, tasks.length);
    expect(world.plaza, isNotNull);
    expect(world.attention.length, tasks.length);
    expect(world.anomalies, everyElement((TaskAttention a) => a.anomalous));
    expect(world.billboards.length, lessThanOrEqualTo(billboardSlots));
    expect(world.beacons.first.kind, BeaconKind.home);
    expect(
      world.beacons.where((b) => b.kind == BeaconKind.attention).length,
      world.anomalies.length,
    );
  });

  test('billboard slots are pylons then mounted screens, rank order', () {
    final ranks = world.billboardSlots.map((s) => s.rank).toList();
    expect(ranks, [0, 1, 2, 3, 4, 5]);
    expect(world.billboardSlots.take(4).every((s) => s.onPylon), isTrue);
    expect(world.mountedScreens.every((s) => !s.onPylon), isTrue);
  });

  test('tickers: mounted screens, the gantry, and the hero rooflines', () {
    expect(world.gantry, isNotNull);
    expect(world.tickers.length, 3 + world.heroes.length);
    expect(world.heroes.length, lessThanOrEqualTo(2));
    // Heroes are the tallest buildings that carry no roof billboard, so a
    // roofline ticker never covers a billboard.
    final roofed = {
      for (final s in world.roofBillboards) world.anomalies[s.rank].task.id,
    };
    for (final hero in world.heroes) {
      expect(roofed, isNot(contains(hero.task.id)));
    }
    expect(world.countsText, startsWith('Synthetic   ·   '));
    expect(world.countsText, isNot(contains('—')));
  });

  test('labels and counts for the HUD', () {
    expect(world.liveTaskCount, tasks.where((t) => !t.deleted).length);
    expect(
      world.builtWeeks,
      world.plan.segments.where((s) => !s.isGap).length,
    );
    expect(world.weekLabel(0), startsWith('W1 · '));
    expect(world.weekOf(tasks.first), startsWith('W'));
    final work = tasks.firstWhere((t) => t.categoryColor == 0xFF5C9DFF);
    expect(world.categoryLabelOf(work), 'work');
    final other = tasks.firstWhere((t) => t.categoryColor != 0xFF5C9DFF);
    expect(world.categoryLabelOf(other), 'task');
  });

  test('ticker text leads with the project and the attention count', () {
    expect(
      world.tickerText,
      startsWith('Synthetic   ·   ${world.anomalies.length} need attention'),
    );
    expect(world.tickerText, contains('in progress'));
    expect(world.tickerText, endsWith('of ${world.liveTaskCount} done'));
  });

  test('street furniture is derived with the world', () {
    expect(world.jumbotron, isNotNull);
    expect(world.spires, hasLength(2));
    expect(world.lampPosts, isNotEmpty);
    expect(
      world.banners.map((b) => b.taskId).toSet(),
      world.plan.placements.values
          .where((p) => p.height >= 12)
          .map((p) => p.taskId)
          .toSet(),
    );
  });

  test('walk stops exist when there is a plaza', () {
    expect(world.walkStops, isNotNull);
    expect(world.walkStops!.first.pose, world.plaza!.overview);
    final empty = PlazaWorld(
      tasks: const [],
      now: DateTime.utc(2026),
      projectLabel: 'Empty',
      layout: StreetLayout(projectSeed: 1),
    );
    expect(empty.plaza, isNull);
    expect(empty.walkStops, isNull);
    expect(empty.beacons, isEmpty);
  });
}
