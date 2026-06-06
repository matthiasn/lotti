import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_update_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart' show setUpTestGetIt, tearDownTestGetIt;
import '../test_utils.dart' show ChecklistTestDataFactory;

// Mocks
void main() {
  late MockChecklistRepository mockChecklistRepository;
  late MockJournalDb mockJournalDb;
  late LottiChecklistUpdateHandler handler;
  late Task testTask;

  setUpAll(() {
    registerFallbackValue(
      const ChecklistItemData(
        title: 'fallback',
        isChecked: false,
        linkedChecklists: [],
      ),
    );
  });

  setUp(() async {
    mockChecklistRepository = MockChecklistRepository();
    // Registers core services in GetIt; the handler resolves JournalDb
    // through the locator.
    final mocks = await setUpTestGetIt();
    mockJournalDb = mocks.journalDb;

    testTask = ChecklistTestDataFactory.createTask(
      checklistIds: ['checklist-1'],
    );

    handler = LottiChecklistUpdateHandler(
      task: testTask,
      checklistRepository: mockChecklistRepository,
    );
  });

  tearDown(tearDownTestGetIt);

  /// Stubs the JournalDb fetch for [ids] to return the serialized [items].
  void stubItemFetch(List<String> ids, List<ChecklistItem> items) {
    when(
      () => mockJournalDb.entriesForIds(ids),
    ).thenReturn(
      MockSelectable<JournalDbEntity>(items.map(_createDbEntity).toList()),
    );
  }

  /// Stubs the task lookup the handler performs before applying updates.
  void stubTaskById() {
    when(
      () => mockJournalDb.journalEntityById(testTask.id),
    ).thenAnswer((_) async => testTask);
  }

  /// Stubs a successful repository write for [checklistItemId].
  void stubUpdateSuccess(String checklistItemId) {
    when(
      () => mockChecklistRepository.updateChecklistItem(
        checklistItemId: checklistItemId,
        data: any(named: 'data'),
        taskId: testTask.id,
      ),
    ).thenAnswer((_) async => true);
  }

  /// Builds the canonical successful processFunctionCall result carrying
  /// [items] for the handler's executeUpdates stage.
  FunctionCallResult makeUpdateResult(List<Map<String, dynamic>> items) =>
      FunctionCallResult(
        success: true,
        functionName: 'update_checklist_items',
        arguments: '',
        data: {
          'items': items,
          'taskId': testTask.id,
        },
      );

  group('LottiChecklistUpdateHandler', () {
    test('should have correct function name', () {
      expect(handler.functionName, 'update_checklist_items');
    });

    group('processFunctionCall', () {
      test('should process valid update with isChecked: true', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items.length, 1);
        expect(items[0]['id'], 'item-1');
        expect(items[0]['isChecked'], true);
      });

      test(
        'should process valid update with isChecked: false (unchecking)',
        () {
          final toolCall = ChecklistTestDataFactory.createToolCall(
            functionName: 'update_checklist_items',
            arguments: '{"items": [{"id": "item-1", "isChecked": false}]}',
          );

          final result = handler.processFunctionCall(toolCall);

          expect(result.success, true);
          final items = (result.data['items'] as List)
              .cast<Map<String, dynamic>>();
          expect(items[0]['isChecked'], false);
        },
      );

      test('should process valid update with title only', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "title": "Updated title"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items[0]['title'], 'Updated title');
        expect(items[0].containsKey('isChecked'), false);
      });

      test('should process valid update with both isChecked and title', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments:
              '{"items": [{"id": "item-1", "isChecked": true, "title": "macOS settings"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items[0]['isChecked'], true);
        expect(items[0]['title'], 'macOS settings');
      });

      test('should normalize whitespace in title', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments:
              '{"items": [{"id": "item-1", "title": "  foo   bar  baz  "}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items[0]['title'], 'foo bar baz');
      });

      test('should trim id whitespace', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "  item-1  ", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items[0]['id'], 'item-1');
      });

      test('should reject empty items array', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": []}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Empty items array'));
      });

      test('should reject item without id', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('missing required "id" field'));
      });

      test('should reject item with empty id', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('missing required "id" field'));
      });

      test('should reject item with whitespace-only id', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "   ", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('missing required "id" field'));
      });

      test('should reject item without any update field', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('has no update fields'));
      });

      test('should reject title exceeding 400 chars after normalization', () {
        final longTitle = 'a' * 401;
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "title": "$longTitle"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('exceeding 400 characters'));
      });

      test('should accept title exactly 400 chars', () {
        final exactTitle = 'a' * 400;
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "title": "$exactTitle"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
      });

      test('should reject empty title after normalization', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "title": "   "}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('empty title after normalization'));
      });

      test('should reject invalid isChecked type', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "isChecked": "yes"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('invalid isChecked value'));
      });

      test('should reject invalid title type', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "title": 123}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('invalid title value'));
      });

      test('should reject non-object items', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": ["item-1", "item-2"]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('is not an object'));
      });

      test('should reject non-array items', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": "item-1"}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Invalid or missing "items"'));
      });

      test('should reject missing items field', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"wrong": "value"}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Invalid or missing "items"'));
      });

      test('should reject batch exceeding max size (20)', () {
        final items = List.generate(
          21,
          (i) => '{"id": "item-$i", "isChecked": true}',
        ).join(', ');
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [$items]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Maximum batch size is 20'));
      });

      test('should accept exactly 20 items', () {
        final items = List.generate(
          20,
          (i) => '{"id": "item-$i", "isChecked": true}',
        ).join(', ');
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [$items]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final parsedItems = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(parsedItems.length, 20);
      });

      test('should reject invalid JSON', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: 'invalid json',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Invalid JSON'));
      });

      test('should reject function name mismatch', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'wrong_function',
          arguments: '{"items": [{"id": "item-1", "isChecked": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('Function name mismatch'));
      });

      test('should accept isArchived as the only update field', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "isArchived": true}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items.single['isArchived'], true);
      });

      test('should reject invalid isArchived type', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '{"items": [{"id": "item-1", "isArchived": "yes"}]}',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('invalid isArchived'));
      });

      test('should process multiple items', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: '''
            {"items": [
              {"id": "item-1", "isChecked": true},
              {"id": "item-2", "title": "Updated"},
              {"id": "item-3", "isChecked": false, "title": "Both updated"}
            ]}
          ''',
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items.length, 3);
      });
    });

    group('executeUpdates', () {
      test('should update item isChecked status', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Buy groceries',
          checkedBy: ChangeSource.agent,
        );

        stubItemFetch(['item-1'], [item]);
        stubTaskById();
        stubUpdateSuccess('item-1');

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': true},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 1);

        verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: 'item-1',
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).called(1);
      });

      test(
        'archives an item without touching its checked provenance',
        () async {
          final item = ChecklistTestDataFactory.createChecklistItem(
            id: 'item-1',
            title: 'Duplicate entry',
            checkedAt: DateTime(2024, 1, 10),
          );

          stubItemFetch(['item-1'], [item]);
          stubTaskById();
          stubUpdateSuccess('item-1');

          final result = makeUpdateResult([
            {'id': 'item-1', 'isArchived': true},
          ]);

          final count = await handler.executeUpdates(result);

          expect(count, 1);
          final written =
              verify(
                    () => mockChecklistRepository.updateChecklistItem(
                      checklistItemId: 'item-1',
                      data: captureAny(named: 'data'),
                      taskId: testTask.id,
                    ),
                  ).captured.single
                  as ChecklistItemData;
          expect(written.isArchived, true);
          // Archival must not flip checked state or re-stamp provenance.
          expect(written.isChecked, item.data.isChecked);
          expect(written.checkedBy, ChangeSource.user);
          expect(written.checkedAt, DateTime(2024, 1, 10));
        },
      );

      test('skips an archival that matches the current state', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Already archived',
          isArchived: true,
        );

        stubItemFetch(['item-1'], [item]);

        final result = makeUpdateResult([
          {'id': 'item-1', 'isArchived': true},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems.single.reason, 'No changes detected');
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });

      test('a sovereignty-blocked isChecked change still applies the '
          'archival', () async {
        // User checked this item; the agent tries to uncheck it without a
        // reason AND archive it. The uncheck is blocked, the archive lands.
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'User-checked duplicate',
          isChecked: true,
          checkedAt: DateTime(2024, 1, 12),
        );

        stubItemFetch(['item-1'], [item]);
        stubTaskById();
        stubUpdateSuccess('item-1');

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': false, 'isArchived': true},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 1);
        expect(
          handler.skippedItems.single.reason,
          contains('User set this item'),
        );
        final written =
            verify(
                  () => mockChecklistRepository.updateChecklistItem(
                    checklistItemId: 'item-1',
                    data: captureAny(named: 'data'),
                    taskId: testTask.id,
                  ),
                ).captured.single
                as ChecklistItemData;
        expect(written.isArchived, true);
        expect(written.isChecked, true); // the blocked uncheck did NOT land
      });

      test('should update item title', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'mac OS settings',
        );

        stubItemFetch(['item-1'], [item]);
        stubTaskById();
        stubUpdateSuccess('item-1');

        final result = makeUpdateResult([
          {'id': 'item-1', 'title': 'macOS settings'},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 1);
      });

      test('should skip non-existent item', () async {
        stubItemFetch(['missing-item'], []);

        final result = makeUpdateResult([
          {'id': 'missing-item', 'isChecked': true},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems.length, 1);
        expect(handler.skippedItems[0].id, 'missing-item');
        expect(handler.skippedItems[0].reason, 'Item not found');

        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });

      test('should skip item not belonging to task', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          linkedChecklists: ['other-checklist'], // Not checklist-1
        );

        stubItemFetch(['item-1'], [item]);

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': true},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(
          handler.skippedItems[0].reason,
          'Item does not belong to this task',
        );
      });

      test('should skip item with no actual changes', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Already correct',
          isChecked: true, // Already checked
        );

        stubItemFetch(['item-1'], [item]);

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': true}, // Same as current
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems[0].reason, 'No changes detected');
      });

      test('should handle mixed valid and invalid items', () async {
        final validItem = ChecklistTestDataFactory.createChecklistItem(
          id: 'valid-item',
          title: 'Valid',
          checkedBy: ChangeSource.agent,
        );

        stubItemFetch(['valid-item', 'missing-item'], [validItem]);
        stubTaskById();
        stubUpdateSuccess('valid-item');

        final result = makeUpdateResult([
          {'id': 'valid-item', 'isChecked': true},
          {'id': 'missing-item', 'isChecked': true},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 1);
        expect(handler.skippedItems.length, 1);
      });

      test('should return 0 for unsuccessful result', () async {
        const result = FunctionCallResult(
          success: false,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {},
          error: 'Some error',
        );

        final count = await handler.executeUpdates(result);

        expect(count, 0);
      });

      test('should skip all items if task has no checklists', () async {
        final taskWithoutChecklists = ChecklistTestDataFactory.createTask(
          checklistIds: [],
        );

        handler = LottiChecklistUpdateHandler(
          task: taskWithoutChecklists,
          checklistRepository: mockChecklistRepository,
        );

        final result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true},
            ],
            'taskId': taskWithoutChecklists.id,
          },
        );

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems[0].reason, 'Task has no checklists');
      });

      test('should invoke onTaskUpdated callback on success', () async {
        var callbackInvoked = false;
        Task? updatedTask;

        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          onTaskUpdated: (task) {
            callbackInvoked = true;
            updatedTask = task;
          },
        );

        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          checkedBy: ChangeSource.agent,
        );

        final refreshedTask = ChecklistTestDataFactory.createTask(
          id: testTask.id,
          checklistIds: ['checklist-1'],
        );

        stubItemFetch(['item-1'], [item]);
        when(
          () => mockJournalDb.journalEntityById(testTask.id),
        ).thenAnswer((_) async => refreshedTask);
        stubUpdateSuccess('item-1');

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': true},
        ]);

        await handler.executeUpdates(result);

        expect(callbackInvoked, true);
        // The callback must receive the REFRESHED entity from the post-update
        // journalEntityById read, not the handler's original (stale) task.
        expect(identical(updatedTask, refreshedTask), isTrue);
        expect(updatedTask!.data.checklistIds, ['checklist-1']);
      });
    });

    group('normalizeWhitespace', () {
      test('should trim leading and trailing whitespace', () {
        expect(
          LottiChecklistUpdateHandler.normalizeWhitespace('  hello  '),
          'hello',
        );
      });

      test('should collapse multiple internal spaces', () {
        expect(
          LottiChecklistUpdateHandler.normalizeWhitespace('hello   world'),
          'hello world',
        );
      });

      test('should handle tabs and newlines', () {
        expect(
          LottiChecklistUpdateHandler.normalizeWhitespace('hello\t\nworld'),
          'hello world',
        );
      });

      test('should handle mixed whitespace', () {
        expect(
          LottiChecklistUpdateHandler.normalizeWhitespace(
            '  foo   bar  \t baz  ',
          ),
          'foo bar baz',
        );
      });

      glados.Glados(
        glados.any.whitespaceNoisyString,
        glados.ExploreConfig(numRuns: 150),
      ).test(
        'normalization is trimmed, single-spaced, idempotent and '
        'character-preserving',
        (input) {
          final out = LottiChecklistUpdateHandler.normalizeWhitespace(input);

          expect(out, out.trim(), reason: '"$input"');
          expect(out.contains(RegExp(r'\s\s')), isFalse, reason: '"$out"');
          // Idempotent.
          expect(LottiChecklistUpdateHandler.normalizeWhitespace(out), out);
          // Non-whitespace characters survive in order.
          expect(
            out.replaceAll(' ', ''),
            input.replaceAll(RegExp(r'\s'), ''),
            reason: '"$input"',
          );
        },
        tags: 'glados',
      );
    });

    group('isDuplicate', () {
      test('should always return false', () {
        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': true},
        ]);

        expect(handler.isDuplicate(result), false);
      });
    });

    group('getDescription', () {
      test('should return item count for successful result', () {
        const result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {
            'items': [
              {'id': 'item-1', 'isChecked': true},
              {'id': 'item-2', 'title': 'Updated'},
            ],
          },
        );

        expect(handler.getDescription(result), '2 item(s) to update');
      });

      test('should return null for unsuccessful result', () {
        const result = FunctionCallResult(
          success: false,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {},
          error: 'Error',
        );

        expect(handler.getDescription(result), null);
      });

      test('should return null for empty items', () {
        const result = FunctionCallResult(
          success: true,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {'items': <Map<String, dynamic>>[]},
        );

        expect(handler.getDescription(result), null);
      });
    });

    group('createToolResponse', () {
      test('should create JSON response for success', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Original',
          checkedBy: ChangeSource.agent,
        );

        stubItemFetch(['item-1'], [item]);
        stubTaskById();
        stubUpdateSuccess('item-1');

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': true, 'title': 'Updated'},
        ]);

        await handler.executeUpdates(result);

        final response = handler.createToolResponse(result);

        expect(response, contains('Updated 1 item'));
        expect(response, contains('"Updated"'));
        expect(response, contains('isChecked'));
        expect(response, contains('title'));
      });

      test('should create error response for failure', () {
        const result = FunctionCallResult(
          success: false,
          functionName: 'update_checklist_items',
          arguments: '',
          data: {},
          error: 'Invalid format',
        );

        final response = handler.createToolResponse(result);

        expect(response, 'Error updating checklist items: Invalid format');
      });
    });

    group('processFunctionCall — reason field', () {
      test('should pass through valid reason string', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: jsonEncode({
            'items': [
              {
                'id': 'item-1',
                'isChecked': false,
                'reason': 'User said "not done" in 22:30 recording',
              },
            ],
          }),
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items[0]['reason'], 'User said "not done" in 22:30 recording');
      });

      test('should strip whitespace-only reason', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: jsonEncode({
            'items': [
              {'id': 'item-1', 'isChecked': true, 'reason': '   '},
            ],
          }),
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items[0].containsKey('reason'), false);
      });

      test('should reject invalid reason type', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: jsonEncode({
            'items': [
              {'id': 'item-1', 'isChecked': true, 'reason': 123},
            ],
          }),
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, false);
        expect(result.error, contains('invalid reason value'));
      });

      test('should omit null reason from validated items', () {
        final toolCall = ChecklistTestDataFactory.createToolCall(
          functionName: 'update_checklist_items',
          arguments: jsonEncode({
            'items': [
              {'id': 'item-1', 'isChecked': true},
            ],
          }),
        );

        final result = handler.processFunctionCall(toolCall);

        expect(result.success, true);
        final items = (result.data['items'] as List)
            .cast<Map<String, dynamic>>();
        expect(items[0].containsKey('reason'), false);
      });
    });

    group('sovereignty guard', () {
      /// Helper to set up mocks for a single checklist item entity.
      void stubSingleItem(ChecklistItem item) {
        stubItemFetch([item.id], [item]);
        stubTaskById();
        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: item.id,
            data: any(named: 'data'),
            taskId: testTask.id,
          ),
        ).thenAnswer((_) async => true);
      }

      test('blocks isChecked change on user-set item without reason', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Write tests',
          isChecked: true,
          checkedBy:
              ChangeSource.user, // ignore: avoid_redundant_argument_values
          checkedAt: DateTime(2026, 2, 28, 22),
        );
        stubSingleItem(item);

        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          clock: () => DateTime(2026, 2, 28, 22, 35),
        );

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': false},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems.length, 1);
        expect(
          handler.skippedItems[0].reason,
          contains('User set this item at'),
        );
        expect(
          handler.skippedItems[0].reason,
          contains('Provide a reason'),
        );

        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });

      test(
        'blocks user-unchecked item from being checked without reason',
        () async {
          final item = ChecklistTestDataFactory.createChecklistItem(
            id: 'item-1',
            title: 'Not done yet',
            checkedBy:
                ChangeSource.user, // ignore: avoid_redundant_argument_values
            checkedAt: DateTime(2026, 2, 28, 22),
          );
          stubSingleItem(item);

          handler = LottiChecklistUpdateHandler(
            task: testTask,
            checklistRepository: mockChecklistRepository,
            clock: () => DateTime(2026, 2, 28, 22, 35),
          );

          final result = makeUpdateResult([
            {'id': 'item-1', 'isChecked': true},
          ]);

          final count = await handler.executeUpdates(result);

          expect(count, 0);
          expect(handler.skippedItems.length, 1);
          expect(
            handler.skippedItems[0].reason,
            contains('User set this item'),
          );
        },
      );

      test(
        'allows override of user-set item when reason is provided',
        () async {
          final item = ChecklistTestDataFactory.createChecklistItem(
            id: 'item-1',
            title: 'Deploy to prod',
            isChecked: true,
            checkedBy:
                ChangeSource.user, // ignore: avoid_redundant_argument_values
            checkedAt: DateTime(2026, 2, 28, 22),
          );
          stubSingleItem(item);

          final clockTime = DateTime(2026, 2, 28, 22, 35);
          handler = LottiChecklistUpdateHandler(
            task: testTask,
            checklistRepository: mockChecklistRepository,
            clock: () => clockTime,
          );

          final result = makeUpdateResult([
            {
              'id': 'item-1',
              'isChecked': false,
              'reason': 'User said "deploy failed" in 22:30 recording',
            },
          ]);

          final count = await handler.executeUpdates(result);

          expect(count, 1);
          expect(handler.skippedItems, isEmpty);

          final captured =
              verify(
                    () => mockChecklistRepository.updateChecklistItem(
                      checklistItemId: 'item-1',
                      data: captureAny(named: 'data'),
                      taskId: testTask.id,
                    ),
                  ).captured.single
                  as ChecklistItemData;

          expect(captured.isChecked, false);
          expect(captured.checkedBy, ChangeSource.agent);
          expect(captured.checkedAt, clockTime);
        },
      );

      test('freely updates agent-set item without reason', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Auto-detected task',
          isChecked: true,
          checkedBy: ChangeSource.agent,
          checkedAt: DateTime(2026, 2, 28, 21),
        );
        stubSingleItem(item);

        final clockTime = DateTime(2026, 2, 28, 22, 35);
        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          clock: () => clockTime,
        );

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': false},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 1);
        expect(handler.skippedItems, isEmpty);

        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklistItem(
                    checklistItemId: 'item-1',
                    data: captureAny(named: 'data'),
                    taskId: testTask.id,
                  ),
                ).captured.single
                as ChecklistItemData;

        expect(captured.isChecked, false);
        expect(captured.checkedBy, ChangeSource.agent);
        expect(captured.checkedAt, clockTime);
      });

      test(
        'allows title update but blocks isChecked on user-set item',
        () async {
          final item = ChecklistTestDataFactory.createChecklistItem(
            id: 'item-1',
            title: 'mac OS setup',
            isChecked: true,
            checkedBy:
                ChangeSource.user, // ignore: avoid_redundant_argument_values
            checkedAt: DateTime(2026, 2, 28, 22),
          );
          stubSingleItem(item);

          handler = LottiChecklistUpdateHandler(
            task: testTask,
            checklistRepository: mockChecklistRepository,
            clock: () => DateTime(2026, 2, 28, 22, 35),
          );

          final result = makeUpdateResult([
            {
              'id': 'item-1',
              'isChecked': false,
              'title': 'macOS setup',
            },
          ]);

          final count = await handler.executeUpdates(result);

          // Title update succeeds, isChecked skipped
          expect(count, 1);
          expect(handler.skippedItems.length, 1);
          expect(
            handler.skippedItems[0].reason,
            contains('User set this item'),
          );

          final captured =
              verify(
                    () => mockChecklistRepository.updateChecklistItem(
                      checklistItemId: 'item-1',
                      data: captureAny(named: 'data'),
                      taskId: testTask.id,
                    ),
                  ).captured.single
                  as ChecklistItemData;

          expect(captured.title, 'macOS setup');
          // isChecked should remain unchanged (user's value)
          expect(captured.isChecked, true);
          // checkedBy should remain user since isChecked wasn't changed
          expect(captured.checkedBy, ChangeSource.user);
        },
      );

      test('treats legacy item (default checkedBy) as user-set', () async {
        // Legacy items deserialize with checkedBy = user (the default)
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Old item',
          isChecked: true,
          // checkedBy defaults to user, checkedAt defaults to null
        );
        stubSingleItem(item);

        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          clock: () => DateTime(2026, 2, 28, 22, 35),
        );

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': false},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems.length, 1);
        expect(
          handler.skippedItems[0].reason,
          contains('User set this item at unknown'),
        );
      });

      test('treats empty reason as missing', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Task item',
          isChecked: true,
          checkedBy:
              ChangeSource.user, // ignore: avoid_redundant_argument_values
          checkedAt: DateTime(2026, 2, 28, 22),
        );
        stubSingleItem(item);

        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          clock: () => DateTime(2026, 2, 28, 22, 35),
        );

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': false, 'reason': '   '},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems.length, 1);
        expect(
          handler.skippedItems[0].reason,
          contains('User set this item'),
        );
      });

      test('preserves user provenance on title-only update', () async {
        // Title-only updates should NOT change checkedBy/checkedAt
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'mac OS',
          isChecked: true,
          checkedBy:
              ChangeSource.user, // ignore: avoid_redundant_argument_values
          checkedAt: DateTime(2026, 2, 28, 22),
        );
        stubSingleItem(item);

        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          clock: () => DateTime(2026, 2, 28, 22, 35),
        );

        final result = makeUpdateResult([
          {'id': 'item-1', 'title': 'macOS'},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 1);

        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklistItem(
                    checklistItemId: 'item-1',
                    data: captureAny(named: 'data'),
                    taskId: testTask.id,
                  ),
                ).captured.single
                as ChecklistItemData;

        // Provenance should be preserved (no isChecked change)
        expect(captured.checkedBy, ChangeSource.user);
        expect(captured.checkedAt, DateTime(2026, 2, 28, 22));
      });

      test('rejects short reason on user-set item', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'Task item',
          isChecked: true,
          checkedBy:
              ChangeSource.user, // ignore: avoid_redundant_argument_values
          checkedAt: DateTime(2026, 2, 28, 22),
        );
        stubSingleItem(item);

        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          clock: () => DateTime(2026, 2, 28, 22, 35),
        );

        final result = makeUpdateResult([
          {'id': 'item-1', 'isChecked': false, 'reason': 'not done'},
        ]);

        final count = await handler.executeUpdates(result);

        expect(count, 0);
        expect(handler.skippedItems.length, 1);
        expect(
          handler.skippedItems[0].reason,
          contains('Reason too short'),
        );
        expect(
          handler.skippedItems[0].reason,
          contains('minimum ${LottiChecklistUpdateHandler.minReasonLength}'),
        );
      });

      test('rejects short reason but still applies title update', () async {
        final item = ChecklistTestDataFactory.createChecklistItem(
          id: 'item-1',
          title: 'mac OS setup',
          isChecked: true,
          checkedBy:
              ChangeSource.user, // ignore: avoid_redundant_argument_values
          checkedAt: DateTime(2026, 2, 28, 22),
        );
        stubSingleItem(item);

        handler = LottiChecklistUpdateHandler(
          task: testTask,
          checklistRepository: mockChecklistRepository,
          clock: () => DateTime(2026, 2, 28, 22, 35),
        );

        final result = makeUpdateResult([
          {
            'id': 'item-1',
            'isChecked': false,
            'title': 'macOS setup',
            'reason': 'short',
          },
        ]);

        final count = await handler.executeUpdates(result);

        // Title update succeeds, isChecked blocked
        expect(count, 1);
        expect(handler.skippedItems.length, 1);
        expect(
          handler.skippedItems[0].reason,
          contains('Reason too short'),
        );

        final captured =
            verify(
                  () => mockChecklistRepository.updateChecklistItem(
                    checklistItemId: 'item-1',
                    data: captureAny(named: 'data'),
                    taskId: testTask.id,
                  ),
                ).captured.single
                as ChecklistItemData;

        expect(captured.title, 'macOS setup');
        // isChecked should remain unchanged (user's value)
        expect(captured.isChecked, true);
      });
    });

    group('getRetryPrompt', () {
      test('should include error summary and format instructions', () {
        final failedItems = [
          const FunctionCallResult(
            success: false,
            functionName: 'update_checklist_items',
            arguments: '',
            data: {},
            error: 'Missing id field',
          ),
        ];

        final prompt = handler.getRetryPrompt(
          failedItems: failedItems,
          successfulDescriptions: ['item-1'],
        );

        expect(prompt, contains('Missing id field'));
        expect(prompt, contains('"id"'));
        expect(prompt, contains('"isChecked"'));
        expect(prompt, contains('"title"'));
      });
    });
  });
}

/// Helper to create a JournalDbEntity from a ChecklistItem for mocking.
JournalDbEntity _createDbEntity(ChecklistItem item) {
  return JournalDbEntity(
    id: item.id,
    createdAt: item.meta.createdAt,
    updatedAt: item.meta.updatedAt,
    dateFrom: item.meta.dateFrom,
    dateTo: item.meta.dateTo,
    type: 'ChecklistItem',
    serialized: jsonEncode({
      'runtimeType': 'checklistItem',
      'meta': {
        'id': item.meta.id,
        'createdAt': item.meta.createdAt.toIso8601String(),
        'updatedAt': item.meta.updatedAt.toIso8601String(),
        'dateFrom': item.meta.dateFrom.toIso8601String(),
        'dateTo': item.meta.dateTo.toIso8601String(),
        'categoryId': item.meta.categoryId,
      },
      'data': {
        'title': item.data.title,
        'isChecked': item.data.isChecked,
        'isArchived': item.data.isArchived,
        'linkedChecklists': item.data.linkedChecklists,
        'checkedBy': item.data.checkedBy.name,
        if (item.data.checkedAt != null)
          'checkedAt': item.data.checkedAt!.toIso8601String(),
      },
    }),
    schemaVersion: 1,
    deleted: false,
    private: false,
    starred: false,
    task: false,
    flag: 0,
    category: item.meta.categoryId ?? '',
  );
}

extension _AnyWhitespaceNoisyString on glados.Any {
  /// Strings mixing words with runs of spaces, tabs and newlines.
  glados.Generator<String> get whitespaceNoisyString =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 1 << 16),
        glados.IntAnys(this).intInRange(0, 12),
        (int seed, int parts) {
          const words = ['alpha', 'beta', 'gamma', '', 'd-e', 'f.g'];
          const gaps = [' ', '  ', '\t', '\n', ' \t ', '\n\n', ''];
          final buffer = StringBuffer(gaps[seed % gaps.length]);
          for (var i = 0; i < parts; i++) {
            buffer
              ..write(words[(seed + i * 7) % words.length])
              ..write(gaps[(seed + i * 5) % gaps.length]);
          }
          return buffer.toString();
        },
      );
}
