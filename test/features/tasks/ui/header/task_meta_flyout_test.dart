import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_flyout.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_section.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../ai_consumption/test_utils.dart';

class _FakeTaskProgressController extends TaskProgressController {
  @override
  Future<TaskProgressState?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 4, 20, 12);
  const taskId = 'task-1';

  final task = Task(
    meta: Metadata(
      id: taskId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
    ),
    data: TaskData(
      status: TaskStatus.open(id: 'status-1', createdAt: now, utcOffset: 0),
      dateFrom: now,
      dateTo: now,
      statusHistory: const [],
      title: 'Test Task',
    ),
  );

  setUp(() async {
    final mockCache = MockEntitiesCacheService();
    when(() => mockCache.showPrivateEntries).thenReturn(true);
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getLabelById(any())).thenReturn(null);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<EditorStateService>(MockEditorStateService())
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<NavService>(MockNavService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('opens the metadata section in a titled modal', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryControllerProvider(
            taskId,
          ).overrideWith(() => FakeEntryController(task)),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(const []),
          ),
          projectForTaskProvider(taskId).overrideWith((ref) async => null),
          taskProgressControllerProvider(
            taskId,
          ).overrideWith(_FakeTaskProgressController.new),
          taskConsumptionTotalsProvider(
            taskId,
          ).overrideWith((ref) => Stream.value(makeConsumptionTotals())),
        ],
        child: makeTestableWidgetNoScroll(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => TaskMetaFlyout.show(context, taskId: taskId),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Task details'), findsOneWidget);
    final section = tester.widget<TaskMetaSection>(
      find.byType(TaskMetaSection),
    );
    expect(section.taskId, taskId);
    // The modal host keeps the two-column measure; only the persistent
    // column stacks its rows.
    expect(section.density, TaskMetaDensity.wide);
  });
}
