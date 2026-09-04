import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

import '../plaza_fixtures.dart';

PlazaTask _task(PlazaTaskState state, {int color = 0xFF5C9DFF}) => PlazaTask(
  id: 'style-${state.name}',
  createdAt: DateTime.utc(2026, 7),
  title: 'Style probe',
  state: state,
  progress: 0,
  checklistItems: 0,
  linkedTaskIds: const [],
  categoryColor: color,
);

void main() {
  final now = DateTime.utc(2026, 7, 15);

  test('the light bar is green on a finished shop, the state colour else', () {
    final done = attentionFor(_task(PlazaTaskState.done), now);
    expect(done.lantern, LanternState.off);
    expect(PlazaStyle.lightBar(done), const Color(0xFF7AB889));
    final blocked = attentionFor(_task(PlazaTaskState.blocked), now);
    expect(
      PlazaStyle.lightBar(blocked),
      PlazaStyle.lantern(LanternState.blocked),
    );
  });

  test('neon saturates and brightens a hue and leaves grey alone', () {
    const grey = Color(0xFF808080);
    expect(PlazaStyle.neon(grey), grey);
    const blue = Color(0xFF3355AA);
    final base = HSLColor.fromColor(blue);
    final neon = HSLColor.fromColor(PlazaStyle.neon(blue));
    expect(neon.saturation, greaterThan(base.saturation));
    expect(neon.lightness, closeTo(0.62, 0.01));
    expect(neon.hue, closeTo(base.hue, 1));
  });

  test('beacon colours: home white, navigation teal, attention by state', () {
    final tasks = syntheticPlazaTasks();
    final world = PlazaWorld(
      tasks: tasks,
      now: syntheticNow(tasks),
      projectLabel: 'Test',
      layout: StreetLayout(projectSeed: 1337),
    );
    final byKind = <BeaconKind, Beacon>{
      for (final b in world.beacons) b.kind: b,
    };
    expect(
      PlazaStyle.beaconColor(byKind[BeaconKind.home]!, world),
      const Color(0xFFF2FFFA),
    );
    for (final kind in [BeaconKind.block, BeaconKind.corner]) {
      final beacon = byKind[kind];
      if (beacon == null) continue;
      expect(
        PlazaStyle.beaconColor(beacon, world),
        PlazaStyle.teal,
        reason: '$kind',
      );
    }
    final attention = byKind[BeaconKind.attention]!;
    expect(
      PlazaStyle.beaconColor(attention, world),
      PlazaStyle.lantern(world.attention[attention.taskId]!.lantern),
    );
    // A beacon for a task the world no longer knows falls back to teal.
    final orphan = Beacon(
      id: 'orphan',
      kind: BeaconKind.attention,
      label: 'gone',
      pose: attention.pose,
      markerX: 0,
      markerY: 0,
      markerZ: 0,
      taskId: 'missing',
    );
    expect(PlazaStyle.beaconColor(orphan, world), PlazaStyle.teal);
  });

  test('category colours: the category itself, then two darker tints', () {
    final task = _task(PlazaTaskState.open, color: 0xFFFF0000);
    expect(PlazaStyle.categoryBright(task), const Color(0xFFFF0000));
    final wall = HSLColor.fromColor(PlazaStyle.categoryWall(task));
    final roof = HSLColor.fromColor(PlazaStyle.categoryRoof(task));
    // Still red: the hue sits at the top or the bottom of the wheel.
    bool red(double hue) => hue < 10 || hue > 350;
    expect(red(wall.hue), isTrue, reason: 'wall hue ${wall.hue}');
    expect(red(roof.hue), isTrue, reason: 'roof hue ${roof.hue}');
    expect(wall.lightness, greaterThan(roof.lightness));
    expect(wall.lightness, lessThan(0.5));
  });
}
