import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/checklist_migration_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockChecklistRepository mockChecklistRepository;
  late MockJournalDb mockJournalDb;
  late ChecklistMigrationHandler handler;

  const sourceTaskId = 'source-task-001';
  const targetTaskId = 'target-task-001';
  const itemId = 'item-001';
  const checklistId = 'checklist-001';
  const targetChecklistId = 'checklist-002';

  ChecklistItem makeChecklistItem({
    String id = itemId,
    String title = 'Buy milk',
    bool isChecked = false,
    List<String> linkedChecklists = const ['checklist-001'],
  }) {
    return JournalEntity.checklistItem(
          meta: Metadata(
            id: id,
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          ),
          data: ChecklistItemData(
            title: title,
            isChecked: isChecked,
            linkedChecklists: linkedChecklists,
          ),
        )
        as ChecklistItem;
  }

  Task makeTask({
    required String id,
    List<String>? checklistIds,
    String? categoryId,
  }) {
    return Task(
      meta: Metadata(
        id: id,
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        categoryId: categoryId,
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
        title: 'Task $id',
        checklistIds: checklistIds,
      ),
    );
  }

  setUp(() {
    mockChecklistRepository = MockChecklistRepository();
    mockJournalDb = MockJournalDb();
    handler = ChecklistMigrationHandler(
      checklistRepository: mockChecklistRepository,
      journalDb: mockJournalDb,
    );
  });

  group('ChecklistMigrationHandler', () {
    group('validation', () {
      test('returns failure when item id is missing', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'targetTaskId': targetTaskId},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"id" must be a non-empty string'));
      });

      test('returns failure when targetTaskId is missing', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'id': itemId},
        );

        expect(result.success, isFalse);
        expect(
          result.output,
          contains('"targetTaskId" must be a non-empty string'),
        );
      });

      test('returns failure when checklist item not found', () async {
        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {'id': itemId, 'targetTaskId': targetTaskId},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('checklist item $itemId not found'));
      });

      test('returns failure when source task not found', () async {
        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => makeChecklistItem());

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {'id': itemId, 'targetTaskId': targetTaskId},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('source task $sourceTaskId not found'));
      });

      test(
        'returns failure when item does not belong to source task',
        () async {
          when(
            () => mockJournalDb.journalEntityById(itemId),
          ).thenAnswer(
            (_) async => makeChecklistItem(
              linkedChecklists: ['other-checklist'],
            ),
          );

          when(
            () => mockJournalDb.journalEntityById(sourceTaskId),
          ).thenAnswer(
            (_) async => makeTask(
              id: sourceTaskId,
              checklistIds: [checklistId],
            ),
          );

          final result = await handler.handle(
            sourceTaskId,
            {'id': itemId, 'targetTaskId': targetTaskId},
          );

          expect(result.success, isFalse);
          expect(result.output, contains('does not belong to source task'));
        },
      );
    });

    group('idempotency', () {
      test('skips already-archived items without error', () async {
        final archivedItem =
            JournalEntity.checklistItem(
                  meta: Metadata(
                    id: itemId,
                    dateFrom: DateTime(2024, 3, 15),
                    dateTo: DateTime(2024, 3, 15),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2024, 3, 15),
                  ),
                  data: const ChecklistItemData(
                    title: 'Already archived',
                    isChecked: false,
                    isArchived: true,
                    linkedChecklists: ['checklist-001'],
                  ),
                )
                as ChecklistItem;

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => archivedItem);

        final result = await handler.handle(
          sourceTaskId,
          {'id': itemId, 'targetTaskId': targetTaskId},
        );

        expect(result.success, isTrue);
        expect(result.output, contains('already archived'));

        // Should not attempt any migration operations.
        verifyNever(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        );
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });

    group('migration — target has existing checklist', () {
      test('archives item in source and copies to target', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [targetChecklistId],
            categoryId: 'cat-002',
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => makeChecklistItem(
            id: 'new-item-001',
            linkedChecklists: [targetChecklistId],
          ),
        );

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isTrue);
        expect(result.output, contains('Migrated'));
        expect(result.output, contains('Buy milk'));
        expect(result.mutatedEntityId, targetTaskId);

        // Verify archival.
        final archiveCaptured = verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: captureAny(named: 'checklistItemId'),
            data: captureAny(named: 'data'),
            taskId: captureAny(named: 'taskId'),
          ),
        ).captured;

        expect(archiveCaptured[0], itemId);
        final archivedData = archiveCaptured[1] as ChecklistItemData;
        expect(archivedData.isArchived, isTrue);
        expect(archiveCaptured[2], sourceTaskId);

        // Verify copy creation in target.
        verify(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: targetChecklistId,
            title: 'Buy milk',
            isChecked: false,
            categoryId: 'cat-002',
          ),
        ).called(1);
      });

      test('preserves isChecked state when copying', () async {
        final checkedItem = makeChecklistItem(isChecked: true);

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => checkedItem);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [targetChecklistId],
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => makeChecklistItem(
            id: 'new-item-002',
            isChecked: true,
            linkedChecklists: [targetChecklistId],
          ),
        );

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isTrue);

        verify(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: targetChecklistId,
            title: 'Buy milk',
            isChecked: true,
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);
      });
    });

    group('migration — target has no checklist', () {
      test('creates checklist on target task', () async {
        final item = makeChecklistItem();
        final createdChecklist = JournalEntity.checklist(
          meta: Metadata(
            id: 'auto-created-checklist',
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          ),
          data: const ChecklistData(
            title: 'TODOs',
            linkedChecklistItems: [],
            linkedTasks: [],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        // Target has no checklists.
        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [],
          ),
        );

        when(
          () => mockChecklistRepository.createChecklist(
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer(
          (_) async => (
            checklist: createdChecklist,
            createdItems: <({String id, String title, bool isChecked})>[],
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => makeChecklistItem(
            id: 'new-item-003',
            linkedChecklists: ['auto-created-checklist'],
          ),
        );

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isTrue);

        verify(
          () => mockChecklistRepository.createChecklist(
            taskId: targetTaskId,
          ),
        ).called(1);

        verify(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: 'auto-created-checklist',
            title: 'Buy milk',
            isChecked: false,
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);
      });

      test('returns failure when createChecklist fails', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [],
          ),
        );

        when(
          () => mockChecklistRepository.createChecklist(
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer(
          (_) async => (
            checklist: null,
            createdItems: <({String id, String title, bool isChecked})>[],
          ),
        );

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Target checklist creation failed');

        // Source item should NOT be archived when target checklist
        // creation fails.
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });

    group('migration — edge cases', () {
      test('returns failure when target task not found', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isFalse);
        expect(result.output, contains('target task $targetTaskId not found'));

        // Source item should NOT be archived when target validation fails.
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });

      test(
        'returns success with warning when archival fails after copy',
        () async {
          final item = makeChecklistItem();

          when(
            () => mockJournalDb.journalEntityById(itemId),
          ).thenAnswer((_) async => item);

          when(
            () => mockJournalDb.journalEntityById(sourceTaskId),
          ).thenAnswer(
            (_) async => makeTask(
              id: sourceTaskId,
              checklistIds: [checklistId],
            ),
          );

          when(
            () => mockJournalDb.journalEntityById(targetTaskId),
          ).thenAnswer(
            (_) async => makeTask(
              id: targetTaskId,
              checklistIds: [targetChecklistId],
            ),
          );

          when(
            () => mockChecklistRepository.addItemToChecklist(
              checklistId: any(named: 'checklistId'),
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (_) async => makeChecklistItem(
              id: 'new-item-copy',
              linkedChecklists: [targetChecklistId],
            ),
          );

          // Copy succeeds but archival fails.
          when(
            () => mockChecklistRepository.updateChecklistItem(
              checklistItemId: any(named: 'checklistItemId'),
              data: any(named: 'data'),
              taskId: any(named: 'taskId'),
            ),
          ).thenAnswer((_) async => false);

          final result = await handler.handle(
            sourceTaskId,
            {
              'id': itemId,
              'title': 'Buy milk',
              'targetTaskId': targetTaskId,
            },
          );

          // Success to prevent retry (which would duplicate the copy).
          expect(result.success, isTrue);
          expect(result.errorMessage, 'Source item archival failed');
          expect(result.output, contains('Warning'));
          expect(result.output, contains('not archived'));
          expect(result.mutatedEntityId, targetTaskId);
        },
      );

      test('returns failure when addItemToChecklist returns null', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [targetChecklistId],
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Item copy creation failed');

        // Source item should NOT be archived when copy creation fails.
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });
  });
}
