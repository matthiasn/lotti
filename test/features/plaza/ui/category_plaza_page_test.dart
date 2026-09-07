import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/state/project_plaza_provider.dart';
import 'package:lotti/features/plaza/ui/category_plaza_page.dart';
import 'package:lotti/features/plaza/ui/project_plaza_page.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';
import '../plaza_fixtures.dart';

void main() {
  final category = ManualDemoWorld.penguinLogistics(
    now: manualDemoNow,
  ).categories.first;
  final project = makeTestProject(id: 'waddle', categoryId: category.id);
  final tasks = syntheticPlazaTasks(count: 5);
  final snapshot = CategoryPlazaData(
    category: category,
    projects: [PlazaProjectSummary(project: project, tasks: tasks)],
    dependencyIds: {category.id, project.meta.id},
  );
  late StreamController<CategoryPlazaData?> snapshots;
  late PlazaWorld categoryWorld;
  late PlazaWorld projectWorld;

  setUp(() => snapshots = StreamController<CategoryPlazaData?>());
  tearDown(() => unawaited(snapshots.close()));

  Widget page() => makeTestableWidgetNoScroll(
    CategoryPlazaPage(
      categoryId: category.id,
      sceneBuilder:
          ({
            required world,
            required ticks,
            required onOpenTask,
            required onExit,
          }) {
            if (world.isCategory) {
              categoryWorld = world;
            } else {
              projectWorld = world;
            }
            return Scaffold(
              key: ValueKey(world.isCategory ? 'category' : 'project'),
              body: Column(
                children: [
                  Text(world.projectLabel),
                  TextButton(
                    onPressed: () => onOpenTask(world.tasks.first),
                    child: const Text('Enter'),
                  ),
                  TextButton(onPressed: onExit, child: const Text('Return')),
                ],
              ),
            );
          },
    ),
    overrides: [
      categoryPlazaProvider(
        category.id,
      ).overrideWith((ref) => snapshots.stream),
      projectPlazaProvider(project.meta.id).overrideWith(
        (ref) => Stream.value(
          ProjectPlazaData(
            project: project,
            tasks: tasks,
            dependencyIds: const {},
          ),
        ),
      ),
    ],
  );

  testWidgets(
    'portal enters only its project and Back restores the category scene',
    (tester) async {
      await tester.pumpWidget(page());
      snapshots.add(snapshot);
      await tester.pumpAndSettle();
      final before = categoryWorld;
      expect(before.tasks.single.id, project.meta.id);
      expect(before.tasks.single.project!.taskCount, tasks.length);
      await tester.tap(find.text('Enter'));
      await tester.pumpAndSettle();
      final route = tester.widget<ProjectPlazaPage>(
        find.byType(ProjectPlazaPage),
      );
      expect(route.projectId, project.meta.id);
      expect(route.categoryId, category.id);
      expect(projectWorld.tasks, same(tasks));
      expect(
        projectWorld.plan.placements.keys.toSet(),
        tasks.map((task) => task.id).toSet(),
      );
      await tester.tap(find.text('Return'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectPlazaPage), findsNothing);
      expect(categoryWorld, same(before));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'background error keeps the category, lost access removes its projects',
    (tester) async {
      await tester.pumpWidget(page());
      snapshots.add(snapshot);
      await tester.pumpAndSettle();
      final before = categoryWorld;
      snapshots.addError(StateError('temporary'));
      await tester.pumpAndSettle();
      expect(categoryWorld, same(before));
      expect(find.text('Enter'), findsOneWidget);
      snapshots.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Enter'), findsNothing);
      expect(
        find.text('This category has no visible projects.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
