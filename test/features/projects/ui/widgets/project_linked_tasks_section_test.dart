import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/projects/ui/widgets/project_linked_tasks_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2024, 3, 15);

  late MockNavService mockNavService;

  Task makeTask({
    required String id,
    required String title,
    TaskStatus? status,
  }) {
    return JournalEntity.task(
          meta: Metadata(
            id: id,
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            // ignore: avoid_redundant_argument_values
            vectorClock: null,
          ),
          data: TaskData(
            title: title,
            statusHistory: const [],
            status:
                status ??
                TaskStatus.open(
                  id: uuid.v1(),
                  createdAt: now,
                  utcOffset: 0,
                ),
            dateFrom: now,
            dateTo: now,
          ),
        )
        as Task;
  }

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        mockNavService = MockNavService();
        when(
          () => mockNavService.beamToNamed(any(), data: any(named: 'data')),
        ).thenReturn(null);
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  group('ProjectLinkedTasksSection', () {
    testWidgets('shows "no linked tasks" message when tasks list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProjectLinkedTasksSection(tasks: []),
        ),
      );
      await tester.pump();

      expect(find.text('Linked Tasks'), findsOneWidget);
      expect(find.text('No tasks linked yet'), findsOneWidget);
    });

    testWidgets('shows task titles when tasks are provided', (tester) async {
      final tasks = [
        makeTask(id: 'task-1', title: 'Implement login'),
        makeTask(id: 'task-2', title: 'Fix navigation bug'),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectLinkedTasksSection(tasks: tasks),
        ),
      );
      await tester.pump();

      expect(find.text('Implement login'), findsOneWidget);
      expect(find.text('Fix navigation bug'), findsOneWidget);
      expect(find.text('No tasks linked yet'), findsNothing);
    });

    testWidgets('shows task status labels', (tester) async {
      final tasks = [
        makeTask(id: 'task-1', title: 'Open task'),
        makeTask(
          id: 'task-2',
          title: 'In progress task',
          status: TaskStatus.inProgress(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 0,
          ),
        ),
        makeTask(
          id: 'task-3',
          title: 'Done task',
          status: TaskStatus.done(
            id: uuid.v1(),
            createdAt: now,
            utcOffset: 0,
          ),
        ),
      ];

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProjectLinkedTasksSection(tasks: tasks),
        ),
      );
      await tester.pump();

      expect(find.text('OPEN'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
    });

    testWidgets(
      'taps a task tile and verifies NavService.beamToNamed is called',
      (tester) async {
        final task = makeTask(id: 'task-42', title: 'Tappable task');

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProjectLinkedTasksSection(tasks: [task]),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Tappable task'));
        await tester.pump();

        verify(
          () => mockNavService.beamToNamed('/tasks/task-42'),
        ).called(1);
      },
    );
  });
}
