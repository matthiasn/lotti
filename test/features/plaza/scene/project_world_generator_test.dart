import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/project_world_generator.dart';

import '../../projects/test_utils.dart';
import '../plaza_fixtures.dart';

void main() {
  test('headless generation performance (opt-in)', () {
    for (final count in [28, 100, 500]) {
      final profileTasks = syntheticPlazaTasks(count: count);
      final profileNow = syntheticNow(profileTasks);
      final profileProject = makeTestProject(
        id: 'waddle',
        createdAt: profileTasks.first.createdAt,
      );
      final micros = <int>[];
      for (var sample = 0; sample < 40; sample++) {
        final timer = Stopwatch()..start();
        final world = generateProjectWorld(
          project: profileProject,
          tasks: profileTasks,
          now: profileNow,
        );
        timer.stop();
        expect(world.plan.placements, hasLength(count));
        if (sample >= 10) micros.add(timer.elapsedMicroseconds);
      }
      micros.sort();
      debugPrint(
        'PLAZA_CPU tasks=$count samples=${micros.length} p50_us=${micros[micros.length ~/ 2]} p95_us=${micros[(micros.length * 0.95).floor()]}',
      );
    }
  }, skip: Platform.environment['PLAZA_CPU_PROFILE'] != '1');

  final start = DateTime.utc(2026, 3, 2);
  final project = makeTestProject(id: 'waddle', createdAt: start);
  final tasks = syntheticPlazaTasks(count: 50);
  final now = syntheticNow(tasks);

  test(
    'uses project identity and timeline, never fills missing data with demos',
    () {
      final world = generateProjectWorld(
        project: project,
        tasks: tasks,
        now: now,
      );
      expect(world.plan.epoch, StreetLayout.weekStart(start));
      expect(world.projectLabel, project.data.title);
      expect(
        world.plan.placements.keys.toSet(),
        tasks.map((t) => t.id).toSet(),
      );
      expect(world.layout.scaleBillboardsByPriority, isTrue);
      expect(world.layout.completedSetback, greaterThan(0));
      final empty = generateProjectWorld(
        project: project,
        tasks: const [],
        now: now,
      );
      expect(empty.plan.placements, isEmpty);
      expect(empty.plaza, isNull);
      expect(empty.billboards, isEmpty);
    },
  );

  test('priority scales every attention billboard, retaining its centre', () {
    final probes = [
      for (var priority = 0; priority < 4; priority++)
        PlazaTask(
          id: 'priority-$priority',
          createdAt: start,
          title: 'Attention $priority',
          state: PlazaTaskState.blocked,
          progress: 0,
          checklistItems: 0,
          linkedTaskIds: const [],
          categoryColor: 0,
          priority: priority,
        ),
    ];
    final world = generateProjectWorld(
      project: project,
      tasks: probes,
      now: now,
    );
    final scales = <double>[];
    for (final assignment in world.builtBillboards) {
      final base = world.billboardSlots[assignment.slot.rank];
      expect(assignment.slot.centerY, base.centerY);
      expect(assignment.slot.x, base.x);
      expect(assignment.slot.z, base.z);
      final scale = assignment.slot.width / base.width;
      scales.add(scale);
      expect(assignment.slot.height / base.height, closeTo(scale, 1e-10));
    }
    expect(scales, hasLength(4));
    for (final (i, expected) in [1.0, 0.9, 0.8, 0.7].indexed) {
      expect(scales[i], closeTo(expected, 1e-10));
    }
    expect(
      world.roofPanels.map((panel) => panel.attention.lantern),
      everyElement(LanternState.blocked),
    );
  });

  test(
    'generation is reproducible and configuration survives renderer tuning',
    () {
      const config = ProjectWorldConfig(
        seed: 47,
        weeksPerRow: 2,
        completedSetback: 20,
      );
      final first = generateProjectWorld(
        project: project,
        tasks: tasks,
        now: now,
        config: config,
      );
      final second = generateProjectWorld(
        project: project,
        tasks: tasks.reversed.toList(),
        now: now,
        config: config,
      );
      expect(first.layout.projectSeed, second.layout.projectSeed);
      expect(first.plan.placements.length, second.plan.placements.length);
      for (final p in first.plan.placements.values) {
        final q = second.plan.placements[p.taskId]!;
        expect((p.x, p.z, p.width, p.height), (q.x, q.z, q.width, q.height));
      }
      final tuned = first.layout.copyWith(pxPerMeter: 45);
      expect(tuned.completedSetback, 20);
      expect(tuned.foldEvery, 2);
      expect(tuned.minimumPlotSpacing, config.minimumPlotSpacing);
      expect(tuned.scaleBillboardsByPriority, isTrue);
      expect(
        config.layoutFor('another-project').projectSeed,
        isNot(first.layout.projectSeed),
      );
    },
  );
}
