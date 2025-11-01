import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/tasks/ui/labels/label_selection_modal_content.dart';
import 'package:lotti/features/tasks/ui/labels/task_labels_wrapper.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this.entry);

  final JournalEntity entry;

  @override
  Future<EntryState?> build({required String id}) async {
    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

class _MockLabelsRepository extends Mock implements LabelsRepository {}

JournalEntity taskWithLabels(List<String> labelIds) {
  final now = DateTime(2023);
  return JournalEntity.task(
    meta: Metadata(
      id: 'task-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: [],
      title: 'Sample task',
    ),
  );
}

void main() {
  late MockEntitiesCacheService cacheService;
  late MockEditorStateService editorStateService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late _MockLabelsRepository repository;

  setUpAll(() {
    registerFallbackValue(testLabelDefinition1);
  });

  // Moved toast tests below setup/buildWrapper
  setUp(() async {
    cacheService = MockEntitiesCacheService();
    editorStateService = MockEditorStateService();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    repository = _MockLabelsRepository();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LoggingService>(MockLoggingService());

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(
      () => cacheService.filterLabelsForCategory(
        any(),
        any(),
        includePrivate: any(named: 'includePrivate'),
      ),
    ).thenAnswer(
      (invocation) =>
          invocation.positionalArguments.first as List<LabelDefinition>,
    );
    when(() => cacheService.getLabelById(testLabelDefinition1.id))
        .thenReturn(testLabelDefinition1);
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);
  });

  tearDown(() async {
    await getIt.reset();
  });

  ProviderScope buildWrapper(JournalEntity task) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(id: 'task-123').overrideWith(
          () => _TestEntryController(task),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(
            [testLabelDefinition1, testLabelDefinition2],
          ),
        ),
        labelsRepositoryProvider.overrideWithValue(repository),
      ],
      child: makeTestableWidgetWithScaffold(
        const TaskLabelsWrapper(taskId: 'task-123'),
      ),
    );
  }

  testWidgets('shows toast and performs undo on AI assignment', (tester) async {
    // Register event service for provider
    final eventService = LabelAssignmentEventService();
    getIt.registerSingleton<LabelAssignmentEventService>(eventService);

    // Ensure cache returns label definitions for names
    when(() => cacheService.getLabelById('new-1')).thenReturn(
      testLabelDefinition1.copyWith(id: 'new-1', name: 'New 1'),
    );
    when(() => cacheService.getLabelById('new-2')).thenReturn(
      testLabelDefinition2.copyWith(id: 'new-2', name: 'New 2'),
    );

    // Stub removeLabel
    when(() => repository.removeLabel(
          journalEntityId: any(named: 'journalEntityId'),
          labelId: any(named: 'labelId'),
        )).thenAnswer((_) async => true);

    final task = taskWithLabels(['existing']);
    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    // Publish assignment event
    eventService.publish(
      const LabelAssignmentEvent(
        taskId: 'task-123',
        assignedIds: ['new-1', 'new-2'],
      ),
    );

    await tester.pumpAndSettle();

    // Toast content uses chips; still shows prefix and individual labels
    expect(find.text('Assigned:'), findsOneWidget);
    expect(find.text('New 1'), findsOneWidget);
    expect(find.text('New 2'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    verify(() => repository.removeLabel(
          journalEntityId: 'task-123',
          labelId: 'new-1',
        )).called(1);
    verify(() => repository.removeLabel(
          journalEntityId: 'task-123',
          labelId: 'new-2',
        )).called(1);
  });

  testWidgets('handles rapid multiple assignments, showing latest toast',
      (tester) async {
    // Register event service for provider
    final eventService = LabelAssignmentEventService();
    getIt.registerSingleton<LabelAssignmentEventService>(eventService);

    // Ensure cache returns label definitions
    when(() => cacheService.getLabelById('label-1')).thenReturn(
      testLabelDefinition1.copyWith(id: 'label-1', name: 'Label 1'),
    );
    when(() => cacheService.getLabelById('label-2')).thenReturn(
      testLabelDefinition1.copyWith(id: 'label-2', name: 'Label 2'),
    );
    when(() => cacheService.getLabelById('label-3')).thenReturn(
      testLabelDefinition2.copyWith(id: 'label-3', name: 'Label 3'),
    );

    final task = taskWithLabels(const []);
    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    // First event
    eventService.publish(const LabelAssignmentEvent(
      taskId: 'task-123',
      assignedIds: ['label-1'],
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Second event supersedes toast
    eventService.publish(const LabelAssignmentEvent(
      taskId: 'task-123',
      assignedIds: ['label-2', 'label-3'],
    ));
    await tester.pumpAndSettle();
    // Let the first SnackBar auto-dismiss (default ~4s) and the second one show
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // Assert latest toast shows only the most recent assignment (via chip text)
    expect(find.text('Assigned:'), findsOneWidget);
    expect(find.text('Label 2'), findsOneWidget);
    expect(find.text('Label 1'), findsNothing);
  });

  testWidgets('renders assigned labels as chips', (tester) async {
    final task = taskWithLabels(['label-1']);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
  });

  testWidgets('shows description dialog on long press', (tester) async {
    final task = taskWithLabels(['label-1']);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Urgent'));
    await tester.pumpAndSettle();

    expect(find.text('Requires immediate attention'), findsOneWidget);
  });

  testWidgets('opens selector sheet from edit icon', (tester) async {
    final task = taskWithLabels(['label-1']);
    when(
      () => repository.setLabels(
        journalEntityId: any(named: 'journalEntityId'),
        labelIds: any(named: 'labelIds'),
      ),
    ).thenAnswer((_) async => true);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit labels'));
    await tester.pumpAndSettle();

    // Verify modal opened by checking for the sticky action bar button
    expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
  });

  testWidgets('passes task categoryId to selector content', (tester) async {
    final task = taskWithLabels(['label-1']).copyWith(
      meta: taskWithLabels(['label-1']).meta.copyWith(categoryId: 'work'),
    );

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit labels'));
    await tester.pumpAndSettle();

    final content = tester.widget<LabelSelectionModalContent>(
        find.byType(LabelSelectionModalContent));
    expect(content.categoryId, equals('work'));
  });

  testWidgets('selector content has null categoryId when task has none',
      (tester) async {
    final base = taskWithLabels(const []);
    final task = base.copyWith(meta: base.meta.copyWith(categoryId: null));

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit labels'));
    await tester.pumpAndSettle();

    final content = tester.widget<LabelSelectionModalContent>(
        find.byType(LabelSelectionModalContent));
    expect(content.categoryId, isNull);
  });

  testWidgets('wrapper extracts and passes categoryId to sheet',
      (tester) async {
    final base = taskWithLabels(const []);
    final task = base.copyWith(meta: base.meta.copyWith(categoryId: 'work'));

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    // Tap edit to open selector
    await tester.tap(find.byTooltip('Edit labels'));
    await tester.pumpAndSettle();

    // Verify modal content receives the task's categoryId
    final content = tester.widget<LabelSelectionModalContent>(
        find.byType(LabelSelectionModalContent));
    expect(content.categoryId, equals('work'));
  });

  testWidgets('hides wrapper when no labels assigned and none available',
      (tester) async {
    when(() => cacheService.sortedLabels).thenReturn(const <LabelDefinition>[]);
    final task = taskWithLabels(const []);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    expect(find.text('Labels'), findsNothing);
  });

  testWidgets('shows wrapper when labels available even if none assigned',
      (tester) async {
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);
    final task = taskWithLabels(const []);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    expect(find.text('Labels'), findsOneWidget);
  });

  testWidgets('does not show long-press dialog when no description',
      (tester) async {
    final noDesc = testLabelDefinition1.copyWith(description: null);
    when(() => cacheService.getLabelById(noDesc.id)).thenReturn(noDesc);
    when(() => cacheService.sortedLabels).thenReturn([noDesc]);
    final task = taskWithLabels([noDesc.id]);

    await tester.pumpWidget(buildWrapper(task));
    await tester.pumpAndSettle();

    await tester.longPress(find.text(noDesc.name));
    await tester.pumpAndSettle();

    expect(find.text('Close'), findsNothing);
  });
}
