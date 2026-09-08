import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/category_world_generator.dart';

import '../../projects/test_utils.dart';
import '../plaza_fixtures.dart';

void main() {
  final category = ManualDemoWorld.penguinLogistics(
    now: manualDemoNow,
  ).categories.first;
  final tasks = syntheticPlazaTasks(count: 20);
  final now = syntheticNow(tasks);
  final active = makeTestProject(id: 'active', categoryId: category.id);
  final done = makeTestProject(
    id: 'done',
    categoryId: category.id,
    status: ProjectStatus.completed(
      id: 'completed',
      createdAt: now,
      utcOffset: 0,
    ),
  );
  CategoryPlazaData data(List<PlazaProjectSummary> projects) =>
      CategoryPlazaData(
        category: category,
        projects: projects,
        dependencyIds: const {},
      );
  final summaries = [
    PlazaProjectSummary(project: done, tasks: tasks),
    PlazaProjectSummary(project: active, tasks: tasks),
  ];

  test(
    'one avenue per scoped project, completed away from home, green and quiet',
    () {
      final world = generateCategoryWorld(
        data: data([
          ...summaries,
          PlazaProjectSummary(
            project: makeTestProject(id: 'outside', categoryId: 'other'),
            tasks: tasks,
          ),
        ]),
        now: now,
      );
      expect(world.tasks.map((task) => task.id), ['done', 'active']);
      expect(world.plan.placements.keys, containsAll(['active', 'done']));
      expect(world.avenueByProjectId, {'done': 0, 'active': 1});
      expect(world.weekLabel(0), done.data.title);
      expect(world.plan.placements['done']!.bucketIndex, 0);
      expect(world.layout.foldEvery, 1);
      final home = world.plaza!.home;
      double distance(String id) {
        final plot = world.plan.placements[id]!;
        return groundDistanceBetween(home.x, home.z, plot.x, plot.z);
      }

      expect(distance('done'), greaterThan(distance('active')));

      expect(world.layout.completedSetback, greaterThan(0));
      expect(world.tasks.first.state, PlazaTaskState.done);
      expect(world.attentionOf(world.tasks.first).overdue, isFalse);
      expect(world.attentionOf(world.tasks.first).anomalous, isFalse);
      expect(world.tasks.first.createdAt, done.meta.createdAt);
      expect(world.tasks.last.project!.taskCount, 20);
      expect(world.tasks.first.openChecklistItemIds, isEmpty);
      expect(world.tasks.first.linkedTaskIds, isEmpty);
      expect(world.countsText, contains('2 projects'));
    },
  );

  test(
    'reordering inputs keeps avenues and empty categories invent no projects',
    () {
      final world = generateCategoryWorld(data: data(summaries), now: now);
      final reordered = generateCategoryWorld(
        data: data(summaries.reversed.toList()),
        now: now,
      );
      expect(reordered.avenueByProjectId, world.avenueByProjectId);
      for (final entry in world.plan.placements.entries) {
        final other = reordered.plan.placements[entry.key]!;
        expect((entry.value.x, entry.value.z), (other.x, other.z));
      }
      final empty = generateCategoryWorld(data: data([]), now: now);
      expect(empty.tasks, isEmpty);
      expect(empty.plan.placements, isEmpty);
    },
  );
}
