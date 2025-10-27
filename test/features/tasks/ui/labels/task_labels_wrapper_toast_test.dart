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

JournalEntity _task(String id, {List<String> labelIds = const []}) {
  final now = DateTime(2023);
  return JournalEntity.task(
    meta: Metadata(
      id: id,
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
      title: 'Toast test task',
    ),
  );
}

void main() {
  testWidgets('shows toast with names and Undo removes labels', (tester) async {
    final cacheService = MockEntitiesCacheService();
    final editorStateService = MockEditorStateService();
    final journalDb = MockJournalDb();
    final updateNotifications = MockUpdateNotifications();
    final repo = _MockLabelsRepository();
    final events = LabelAssignmentEventService();
    final loggingService = MockLoggingService();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LabelAssignmentEventService>(events)
      ..registerSingleton<LoggingService>(loggingService);

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(testLabelDefinition1.id))
        .thenReturn(testLabelDefinition1);
    when(() => cacheService.getLabelById(testLabelDefinition2.id))
        .thenReturn(testLabelDefinition2);
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);

    final task = _task('toast-task');
    final widget = ProviderScope(
      overrides: [
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(
            [testLabelDefinition1, testLabelDefinition2],
          ),
        ),
        labelsRepositoryProvider.overrideWithValue(repo),
      ],
      child: makeTestableWidgetWithScaffold(
        TaskLabelsWrapper(taskId: task.meta.id),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Publish event and expect toast
    events.publish(
      LabelAssignmentEvent(
        taskId: task.meta.id,
        assignedIds: [testLabelDefinition1.id, testLabelDefinition2.id],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Assigned:'), findsOneWidget);

    // Tap Undo triggers removeLabel for each id
    when(() => repo.removeLabel(
          journalEntityId: any(named: 'journalEntityId'),
          labelId: any(named: 'labelId'),
        )).thenAnswer((_) async => true);

    when(() => loggingService.captureEvent(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        )).thenAnswer((_) {});

    await tester.tap(find.text('Undo'));
    await tester.pump();

    verify(() => repo.removeLabel(
          journalEntityId: task.meta.id,
          labelId: testLabelDefinition1.id,
        )).called(1);
    verify(() => repo.removeLabel(
          journalEntityId: task.meta.id,
          labelId: testLabelDefinition2.id,
        )).called(1);
  });

  testWidgets('multiple rapid events update latest toast message',
      (tester) async {
    final cacheService = MockEntitiesCacheService();
    final editorStateService = MockEditorStateService();
    final journalDb = MockJournalDb();
    final updateNotifications = MockUpdateNotifications();
    final repo = _MockLabelsRepository();
    final events = LabelAssignmentEventService();
    final loggingService = MockLoggingService();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LabelAssignmentEventService>(events)
      ..registerSingleton<LoggingService>(loggingService);

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(testLabelDefinition1.id))
        .thenReturn(testLabelDefinition1);
    when(() => cacheService.getLabelById(testLabelDefinition2.id))
        .thenReturn(testLabelDefinition2);
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);

    final task = _task('toast-task-2');
    final widget = ProviderScope(
      overrides: [
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(
            [testLabelDefinition1, testLabelDefinition2],
          ),
        ),
        labelsRepositoryProvider.overrideWithValue(repo),
      ],
      child: makeTestableWidgetWithScaffold(
        TaskLabelsWrapper(taskId: task.meta.id),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    events.publish(
      LabelAssignmentEvent(
          taskId: task.meta.id, assignedIds: [testLabelDefinition1.id]),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Assigned:'), findsOneWidget);

    // Publish second event quickly; expect message to reflect latest
    events.publish(
      LabelAssignmentEvent(
          taskId: task.meta.id, assignedIds: [testLabelDefinition2.id]),
    );
    await tester.pumpAndSettle();

    // Still shows a SnackBar for the latest assignment
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('no toast after navigating away (widget unmounted)',
      (tester) async {
    final cacheService = MockEntitiesCacheService();
    final editorStateService = MockEditorStateService();
    final journalDb = MockJournalDb();
    final updateNotifications = MockUpdateNotifications();
    final events = LabelAssignmentEventService();
    final loggingService = MockLoggingService();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LabelAssignmentEventService>(events)
      ..registerSingleton<LoggingService>(loggingService);

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(testLabelDefinition1.id))
        .thenReturn(testLabelDefinition1);
    when(() => cacheService.sortedLabels).thenReturn([testLabelDefinition1]);

    final task = _task('toast-task-3');
    final wrapper = ProviderScope(
      overrides: [
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value([testLabelDefinition1]),
        ),
      ],
      child: makeTestableWidgetWithScaffold(
        TaskLabelsWrapper(taskId: task.meta.id),
      ),
    );

    await tester.pumpWidget(wrapper);
    await tester.pumpAndSettle();

    // Navigate away by replacing the widget tree with same overrides
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryControllerProvider(id: task.meta.id).overrideWith(
            () => _TestEntryController(task),
          ),
          labelsStreamProvider.overrideWith(
            (ref) =>
                Stream<List<LabelDefinition>>.value([testLabelDefinition1]),
          ),
        ],
        child: makeTestableWidgetWithScaffold(const SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();

    // Publish event after unmount; no snackbar should appear
    events.publish(LabelAssignmentEvent(
        taskId: task.meta.id, assignedIds: [testLabelDefinition1.id]));
    await tester.pump();
    expect(find.textContaining('Assigned:'), findsNothing);
  });

  testWidgets('logs undo_triggered metrics when Undo tapped', (tester) async {
    final cacheService = MockEntitiesCacheService();
    final editorStateService = MockEditorStateService();
    final journalDb = MockJournalDb();
    final updateNotifications = MockUpdateNotifications();
    final repo = _MockLabelsRepository();
    final events = LabelAssignmentEventService();
    final loggingService = MockLoggingService();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LabelAssignmentEventService>(events)
      ..registerSingleton<LoggingService>(loggingService);

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(testLabelDefinition1.id))
        .thenReturn(testLabelDefinition1);
    when(() => cacheService.getLabelById(testLabelDefinition2.id))
        .thenReturn(testLabelDefinition2);
    when(() => cacheService.sortedLabels)
        .thenReturn([testLabelDefinition1, testLabelDefinition2]);

    final task = _task('metrics-task');
    final widget = ProviderScope(
      overrides: [
        entryControllerProvider(id: task.meta.id).overrideWith(
          () => _TestEntryController(task),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value(
            [testLabelDefinition1, testLabelDefinition2],
          ),
        ),
        labelsRepositoryProvider.overrideWithValue(repo),
      ],
      child: makeTestableWidgetWithScaffold(
        TaskLabelsWrapper(taskId: task.meta.id),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Publish event and expect toast
    events.publish(
      LabelAssignmentEvent(
        taskId: task.meta.id,
        assignedIds: [testLabelDefinition1.id, testLabelDefinition2.id],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Assigned:'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Setup mocks for undo action
    when(() => repo.removeLabel(
          journalEntityId: any(named: 'journalEntityId'),
          labelId: any(named: 'labelId'),
        )).thenAnswer((_) async => true);

    when(() => loggingService.captureEvent(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        )).thenAnswer((_) {});

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pump();

    // Verify labels were removed
    verify(() => repo.removeLabel(
          journalEntityId: task.meta.id,
          labelId: testLabelDefinition1.id,
        )).called(1);
    verify(() => repo.removeLabel(
          journalEntityId: task.meta.id,
          labelId: testLabelDefinition2.id,
        )).called(1);

    // Verify metrics were logged
    verify(() => loggingService.captureEvent(
          'undo_triggered',
          domain: 'labels_ai_assignment',
          subDomain: 'ui',
        )).called(1);
  });
}
