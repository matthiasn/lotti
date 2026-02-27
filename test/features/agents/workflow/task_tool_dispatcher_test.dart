import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb mockJournalDb;
  late MockJournalRepository mockJournalRepository;
  late MockChecklistRepository mockChecklistRepository;
  late MockLabelsRepository mockLabelsRepository;
  late TaskToolDispatcher dispatcher;

  const taskId = 'task-001';

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockJournalRepository = MockJournalRepository();
    mockChecklistRepository = MockChecklistRepository();
    mockLabelsRepository = MockLabelsRepository();

    dispatcher = TaskToolDispatcher(
      journalDb: mockJournalDb,
      journalRepository: mockJournalRepository,
      checklistRepository: mockChecklistRepository,
      labelsRepository: mockLabelsRepository,
    );
  });

  group('TaskToolDispatcher', () {
    group('dispatch — task lookup', () {
      test('returns failure when task entity is not found', () async {
        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => null);

        final result = await dispatcher.dispatch(
          'set_task_title',
          {'title': 'New Title'},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('not found'));
        expect(result.errorMessage, 'Task lookup failed');
      });

      test('returns failure for unknown tool name', () async {
        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => _makeTestTask(taskId));

        final result = await dispatcher.dispatch(
          'nonexistent_tool',
          <String, dynamic>{},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('Unknown tool: nonexistent_tool'));
        expect(result.errorMessage, contains('not registered'));
      });
    });

    group('dispatch — type validation guards', () {
      setUp(() {
        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => _makeTestTask(taskId));
      });

      test('set_task_title rejects non-string title', () async {
        final result = await dispatcher.dispatch(
          'set_task_title',
          {'title': 42},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"title" must be a string'));
        expect(result.errorMessage, contains('Type validation failed'));
      });

      test('update_task_due_date rejects non-string dueDate', () async {
        final result = await dispatcher.dispatch(
          'update_task_due_date',
          {'dueDate': 123},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"dueDate" must be a non-empty'));
        expect(result.errorMessage, contains('Type validation failed'));
      });

      test('update_task_due_date rejects empty dueDate', () async {
        final result = await dispatcher.dispatch(
          'update_task_due_date',
          {'dueDate': ''},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"dueDate" must be a non-empty'));
      });

      test('update_task_priority rejects non-string priority', () async {
        final result = await dispatcher.dispatch(
          'update_task_priority',
          {'priority': true},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"priority" must be a non-empty'));
      });

      test('update_task_estimate rejects null minutes', () async {
        final result = await dispatcher.dispatch(
          'update_task_estimate',
          <String, dynamic>{},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"minutes" is required'));
        expect(result.errorMessage, 'Missing minutes parameter');
      });

      test('assign_task_labels rejects non-list labels', () async {
        final result = await dispatcher.dispatch(
          'assign_task_labels',
          {'labels': 'not-a-list'},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"labels" must be an array'));
      });

      test('set_task_language rejects non-string languageCode', () async {
        final result = await dispatcher.dispatch(
          'set_task_language',
          {'languageCode': 42},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"languageCode" must be a string'));
      });

      test('set_task_status rejects non-string status', () async {
        final result = await dispatcher.dispatch(
          'set_task_status',
          {'status': 123},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"status" must be a string'));
      });

      test('add_multiple_checklist_items rejects non-list items', () async {
        final result = await dispatcher.dispatch(
          'add_multiple_checklist_items',
          {'items': 'not-a-list'},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"items" must be a non-empty array'));
      });

      test('add_multiple_checklist_items rejects empty list', () async {
        final result = await dispatcher.dispatch(
          'add_multiple_checklist_items',
          {'items': <dynamic>[]},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"items" must be a non-empty array'));
      });

      test('update_checklist_items rejects non-list items', () async {
        final result = await dispatcher.dispatch(
          'update_checklist_items',
          {'items': 'not-a-list'},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"items" must be a non-empty array'));
      });

      test('update_checklist_items rejects empty list', () async {
        final result = await dispatcher.dispatch(
          'update_checklist_items',
          {'items': <dynamic>[]},
          taskId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"items" must be a non-empty array'));
      });
    });

    group('dispatch — handler delegation', () {
      setUp(() {
        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => _makeTestTask(taskId));
      });

      test('set_task_title delegates to TaskTitleHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntityDate(
            any(),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'set_task_title',
          {'title': 'Updated Title'},
          taskId,
        );

        // TaskTitleHandler.handle should succeed for a valid title.
        expect(result.success, isTrue);
        expect(result.output, isNotEmpty);
      });

      test('set_task_status delegates to TaskStatusHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'set_task_status',
          {'status': 'IN PROGRESS'},
          taskId,
        );

        expect(result.success, isTrue);
      });

      test('set_task_language delegates to TaskLanguageHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'set_task_language',
          {'languageCode': 'en'},
          taskId,
        );

        expect(result.success, isTrue);
      });

      test('update_task_estimate delegates to TaskEstimateHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'update_task_estimate',
          {'minutes': 60},
          taskId,
        );

        expect(result.success, isTrue);
      });

      test('update_task_due_date delegates to TaskDueDateHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'update_task_due_date',
          {'dueDate': '2024-12-31'},
          taskId,
        );

        expect(result.success, isTrue);
      });

      test('update_task_priority delegates to TaskPriorityHandler', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(
            any(),
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          'update_task_priority',
          {'priority': 'P1'},
          taskId,
        );

        expect(result.success, isTrue);
      });
    });

    group('dispatch — handlers requiring getIt', () {
      late MockLoggingService mockLoggingService;

      setUp(() {
        mockLoggingService = MockLoggingService();

        // Register getIt dependencies needed by internal handlers.
        getIt
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..registerSingleton<LoggingService>(mockLoggingService)
          ..registerSingleton<LabelAssignmentRateLimiter>(
            LabelAssignmentRateLimiter(),
          );

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => _makeTestTask(taskId));

        // Common stubs for logging service.
        when(
          () => mockLoggingService.captureEvent(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);
        when(
          () => mockLoggingService.captureException(
            any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
            stackTrace: any<dynamic>(named: 'stackTrace'),
          ),
        ).thenReturn(null);
      });

      tearDown(() async {
        await getIt.reset();
      });

      test(
        'assign_task_labels delegates to TaskLabelHandler '
        '(no-op when all labels low confidence)',
        () async {
          // Provide labels with low confidence — the parser drops them,
          // resulting in an early no-op success in TaskLabelHandler.handle.
          // This covers the dispatcher's processor/handler creation and
          // result conversion code path.
          final result = await dispatcher.dispatch(
            'assign_task_labels',
            {
              'labels': [
                {'id': 'label-a', 'confidence': 'low'},
              ],
            },
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, contains('No valid labels'));
        },
      );

      test(
        'assign_task_labels delegates to TaskLabelHandler '
        '(valid labels assigned)',
        () async {
          // Stub label validation: return label as valid.
          when(() => mockJournalDb.getLabelDefinitionById('label-a'))
              .thenAnswer((_) async => _makeLabelDef('label-a'));
          when(() => mockJournalDb.getAllLabelDefinitions())
              .thenAnswer((_) async => [_makeLabelDef('label-a')]);
          when(
            () => mockLabelsRepository.addLabels(
              journalEntityId: any(named: 'journalEntityId'),
              addedLabelIds: any(named: 'addedLabelIds'),
            ),
          ).thenAnswer((_) async => true);

          final result = await dispatcher.dispatch(
            'assign_task_labels',
            {
              'labels': [
                {'id': 'label-a', 'confidence': 'very_high'},
              ],
            },
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, contains('assign_task_labels'));
        },
      );

      test(
        'add_multiple_checklist_items delegates to '
        'LottiBatchChecklistHandler',
        () async {
          // The task has no checklists, so the handler creates a new one
          // via AutoChecklistService.autoCreateChecklist.
          // autoCreateChecklist calls checklistRepository.createChecklist.
          when(
            () => mockChecklistRepository.createChecklist(
              taskId: any(named: 'taskId'),
              items: any(named: 'items'),
              title: any(named: 'title'),
            ),
          ).thenAnswer(
            (_) async => (
              checklist: null,
              createdItems: <({String id, String title, bool isChecked})>[],
            ),
          );

          final result = await dispatcher.dispatch(
            'add_multiple_checklist_items',
            {
              'items': [
                {'title': 'Buy milk'},
                {'title': 'Walk the dog'},
              ],
            },
            taskId,
          );

          // Parsing succeeded — the handler returns success even if
          // checklist creation yielded no items (no-op).
          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );

      test(
        'update_checklist_items delegates to '
        'LottiChecklistUpdateHandler',
        () async {
          // Task has no checklists → handler skips all items.
          final result = await dispatcher.dispatch(
            'update_checklist_items',
            {
              'items': [
                {'id': 'item-001', 'isChecked': true},
              ],
            },
            taskId,
          );

          // Parsing succeeded — the handler returns success=true even
          // when all items are skipped (no-op).
          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );

      test(
        'add_checklist_item wraps as single-element batch',
        () async {
          when(
            () => mockChecklistRepository.createChecklist(
              taskId: any(named: 'taskId'),
              items: any(named: 'items'),
              title: any(named: 'title'),
            ),
          ).thenAnswer(
            (_) async => (
              checklist: null,
              createdItems: <({String id, String title, bool isChecked})>[],
            ),
          );

          final result = await dispatcher.dispatch(
            'add_checklist_item',
            {'title': 'Single item'},
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );

      test(
        'update_checklist_item wraps as single-element batch',
        () async {
          final result = await dispatcher.dispatch(
            'update_checklist_item',
            {'id': 'item-001', 'isChecked': true},
            taskId,
          );

          expect(result.success, isTrue);
          expect(result.output, isNotEmpty);
        },
      );
    });
  });
}

/// Creates a minimal [LabelDefinition] for testing.
LabelDefinition _makeLabelDef(String id) {
  return LabelDefinition(
    id: id,
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    name: 'Label $id',
    color: '#FF0000',
    vectorClock: null,
  );
}

/// Creates a minimal [Task] entity for testing dispatch.
Task _makeTestTask(String id) {
  return Task(
    meta: Metadata(
      id: id,
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: id,
        createdAt: DateTime(2024, 3, 15),
        utcOffset: 0,
      ),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      statusHistory: [],
      title: 'Test Task',
    ),
  );
}
