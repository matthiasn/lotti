import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/features/plaza/data/task_projection.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/state/project_plaza_provider.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/project_plaza_page.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';

void main() {
  final demo = ManualDemoWorld.penguinLogistics(now: manualDemoNow);
  final project = makeTestProject(id: 'waddle', title: 'Project Waddle');
  final task = projectPlazaTask(
    task: demo.tasks.first,
    checklistItems: [
      demo.checklistItems.first.copyWith(
        data: demo.checklistItems.first.data.copyWith(isChecked: false),
      ),
    ],
    categoryColor: 0xFF123456,
    linkedTaskIds: const [],
  );
  final snapshot = ProjectPlazaData(
    project: project,
    category: demo.categories.first,
    tasks: [task],
    dependencyIds: {project.meta.id, task.id},
  );
  late StreamController<ProjectPlazaData?> snapshots;
  late MockPlazaRepository repository;
  late PlazaWorld renderedWorld;
  late ChecklistTicks renderedTicks;
  late ValueChanged<PlazaTask> openTask;

  setUp(() {
    snapshots = StreamController<ProjectPlazaData?>();
    repository = MockPlazaRepository();
  });

  tearDown(() => unawaited(snapshots.close()));

  Widget page({String? categoryId, String? projectId}) => makeTestableWidget(
    SizedBox(
      width: 800,
      height: 600,
      child: ProjectPlazaPage(
        projectId: projectId ?? project.meta.id,
        categoryId: categoryId,
        sceneBuilder:
            ({
              required world,
              required ticks,
              required onOpenTask,
              required onExit,
            }) {
              renderedWorld = world;
              renderedTicks = ticks;
              openTask = onOpenTask;
              return Scaffold(
                body: Text(world.projectLabel, key: const ValueKey('scene')),
              );
            },
      ),
    ),
    overrides: [
      projectPlazaProvider(
        project.meta.id,
      ).overrideWith((ref) => snapshots.stream),
      projectPlazaProvider('other').overrideWith((ref) => const Stream.empty()),
      plazaRepositoryProvider.overrideWithValue(repository),
    ],
  );

  testWidgets('projects live data and writes the durable checklist item', (
    tester,
  ) async {
    await withClock(Clock.fixed(manualDemoNow), () async {
      await tester.pumpWidget(page());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      snapshots.add(snapshot);
      await tester.pump();
      await tester.pump();
      expect(renderedWorld.tasks, same(snapshot.tasks));
      expect(renderedWorld.now.isAtSameMomentAs(manualDemoNow), isTrue);
      expect(renderedWorld.plan.placements.keys, [task.id]);
      expect(
        renderedWorld.categoryLabels[task.categoryColor.toRadixString(16)],
        demo.categories.first.name,
      );
      when(
        () => repository.setChecklistItemChecked(
          projectId: project.meta.id,
          taskId: task.id,
          itemId: task.openChecklistItemIds.first,
          checked: true,
        ),
      ).thenAnswer((_) async => true);
      renderedTicks.toggle(task.id, 0);
      await tester.pump();
      verify(
        () => repository.setChecklistItemChecked(
          projectId: project.meta.id,
          taskId: task.id,
          itemId: task.openChecklistItemIds.first,
          checked: true,
        ),
      ).called(1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('failed checklist edits roll back and explain the failure', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    snapshots.add(snapshot);
    await tester.pump();
    await tester.pump();
    when(
      () => repository.setChecklistItemChecked(
        projectId: project.meta.id,
        taskId: task.id,
        itemId: task.openChecklistItemIds.first,
        checked: true,
      ),
    ).thenAnswer((_) async => false);
    renderedTicks.toggle(task.id, 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final toast = tester.widget<DesignSystemToast>(
      find.byType(DesignSystemToast),
    );
    expect(toast.tone, DesignSystemToastTone.error);
    expect(toast.title, 'Error');
    expect(renderedTicks.isTicked(task.id, 0), isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'changing project scope clears the old scene and checklist bindings',
    (tester) async {
      await tester.pumpWidget(page());
      snapshots.add(snapshot);
      await tester.pump();
      await tester.pump();
      final ticks = renderedTicks;
      await tester.pumpWidget(page(projectId: 'other'));
      await tester.pump();
      expect(find.byKey(const ValueKey('scene')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      ticks.toggle(task.id, 0);
      verifyNever(
        () => repository.setChecklistItemChecked(
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
          itemId: any(named: 'itemId'),
          checked: any(named: 'checked'),
        ),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'opening a billboard pushes the existing details route with its task ID',
    (tester) async {
      await tester.pumpWidget(page());
      snapshots.add(snapshot);
      await tester.pump();
      await tester.pump();
      final context = tester.element(find.byKey(const ValueKey('scene')));
      final navigator = Navigator.of(context);
      openTask(task);
      Route<void>? pushed;
      navigator.popUntil((route) {
        pushed = route;
        return true;
      });
      // Inspect the destination without mounting TaskDetailsPage's separate
      // provider graph. Its own tests exercise the details UI.
      final destination =
          (pushed! as MaterialPageRoute<void>).builder(context)
              as TaskDetailsPage;
      expect(destination.taskId, task.id);
      navigator.removeRoute(pushed!);
      await tester.pump();
      expect(find.text('Project Waddle'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('background error retains the mounted scene then recovers', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    snapshots.add(snapshot);
    await tester.pump();
    await tester.pump();
    final scene = tester.element(find.byKey(const ValueKey('scene')));
    final ticks = renderedTicks;
    final world = renderedWorld;
    snapshots.addError(StateError('temporary database failure'));
    await tester.pump();
    await tester.pump();
    expect(tester.element(find.byKey(const ValueKey('scene'))), same(scene));
    expect(renderedWorld, same(world));
    expect(find.byType(ErrorStateWidget), findsNothing);
    snapshots.add(
      ProjectPlazaData(
        project: project.copyWith(
          data: project.data.copyWith(title: 'Updated'),
        ),
        tasks: [task],
        dependencyIds: snapshot.dependencyIds,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.element(find.byKey(const ValueKey('scene'))), same(scene));
    expect(renderedWorld.projectLabel, 'Updated');
    expect(renderedWorld, isNot(same(world)));
    expect(renderedTicks, same(ticks));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('loss of project access removes every task from the view', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    snapshots.add(snapshot);
    await tester.pump();
    await tester.pump();
    renderedTicks.toggle(task.id, -1);
    snapshots.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('scene')), findsNothing);
    expect(find.text('Project not found'), findsOneWidget);
    renderedTicks.toggle(task.id, 0);
    verifyNever(
      () => repository.setChecklistItemChecked(
        projectId: project.meta.id,
        taskId: any(named: 'taskId'),
        itemId: any(named: 'itemId'),
        checked: any(named: 'checked'),
      ),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a category drilldown stops following a project moved by sync', (
    tester,
  ) async {
    await tester.pumpWidget(page(categoryId: 'selected'));
    snapshots.add(
      ProjectPlazaData(
        project: project.copyWith(
          meta: project.meta.copyWith(categoryId: 'selected'),
        ),
        tasks: [task],
        dependencyIds: snapshot.dependencyIds,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(renderedWorld.tasks.single.id, task.id);
    snapshots.add(
      ProjectPlazaData(
        project: project.copyWith(
          meta: project.meta.copyWith(categoryId: 'outside'),
        ),
        tasks: [task],
        dependencyIds: snapshot.dependencyIds,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('scene')), findsNothing);
    expect(find.text('Project not found'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty projects never initialize the GPU scene', (tester) async {
    await tester.pumpWidget(page());
    snapshots.add(
      ProjectPlazaData(
        project: project,
        tasks: const [],
        dependencyIds: {project.meta.id},
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('scene')), findsNothing);
    expect(
      find.text('Add a task to start building this project’s plaza.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('initial read failure shows an error and later data recovers', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    snapshots.addError(StateError('database failure'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<ErrorStateWidget>(find.byType(ErrorStateWidget)).mode,
      ErrorDisplayMode.inline,
    );
    snapshots.add(snapshot);
    await tester.pump();
    await tester.pump();
    expect(renderedWorld.projectLabel, 'Project Waddle');
    expect(find.byType(ErrorStateWidget), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
