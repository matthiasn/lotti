import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late ChangeSetBuilder builder;
  late MockAgentSyncService mockSyncService;

  setUpAll(() {
    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: 'fallback',
        agentId: 'fallback',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    mockSyncService = MockAgentSyncService();
    builder = ChangeSetBuilder(
      agentId: 'agent-001',
      taskId: 'task-001',
      threadId: 'thread-001',
      runKey: 'run-key-001',
    );

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
  });

  group('addItem', () {
    test('adds a single item to the builder', () {
      builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      expect(builder.hasItems, isTrue);
      expect(builder.items, hasLength(1));
      expect(builder.items.first.toolName, 'update_task_estimate');
      expect(builder.items.first.args, {'minutes': 120});
      expect(builder.items.first.humanSummary, 'Set estimate to 2 hours');
      expect(builder.items.first.status, ChangeItemStatus.pending);
    });

    test('accumulates multiple items in order', () {
      builder
        ..addItem(
          toolName: 'set_task_title',
          args: {'title': 'Fix bug'},
          humanSummary: 'Set title',
        )
        ..addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 60},
          humanSummary: 'Set estimate',
        );

      expect(builder.items, hasLength(2));
      expect(builder.items[0].toolName, 'set_task_title');
      expect(builder.items[1].toolName, 'update_task_estimate');
    });
  });

  group('addBatchItem', () {
    test('explodes add_multiple_checklist_items into individual items',
        () async {
      await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'Design mockup'},
            {'title': 'Implement API'},
            {'title': 'Write tests'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, hasLength(3));
      expect(builder.items[0].toolName, 'add_checklist_item');
      expect(builder.items[0].args, {'title': 'Design mockup'});
      expect(builder.items[0].humanSummary, 'Add: "Design mockup"');
      expect(builder.items[1].humanSummary, 'Add: "Implement API"');
      expect(builder.items[2].humanSummary, 'Add: "Write tests"');
    });

    test('explodes update_checklist_items into individual items', () async {
      await builder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'isChecked': true, 'title': 'Design mockup'},
            {'id': 'item-2', 'title': 'Revised title'},
          ],
        },
        summaryPrefix: 'Checklist update',
      );

      expect(builder.items, hasLength(2));
      expect(builder.items[0].toolName, 'update_checklist_item');
      expect(builder.items[0].args['id'], 'item-1');
      expect(builder.items[0].humanSummary, 'Check: "Design mockup"');
      expect(builder.items[1].humanSummary, contains('Revised title'));
    });

    test('handles check-only update (no title) by ID with truncated ID',
        () async {
      await builder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-42', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, hasLength(1));
      // Short ID — no truncation needed.
      expect(builder.items.first.humanSummary, 'Check off item item-42');
    });

    test('truncates long UUIDs in fallback display', () async {
      await builder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {
              'id': '2ff860d0-141d-11f1-a937-89a8ebc23f0b',
              'isChecked': true,
            },
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, hasLength(1));
      expect(
        builder.items.first.humanSummary,
        'Check off item 2ff860d0…',
      );
    });

    test('resolves title from resolver for ID-only updates', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async {
          if (id == 'item-42') {
            return (title: 'Buy groceries', isChecked: false);
          }
          return null;
        },
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-42', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Check off: "Buy groceries"',
      );
    });

    test('falls back to truncated ID when resolver returns null', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (_) async => null,
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {
              'id': 'abcdefgh-1234-5678-9012-abcdefghijkl',
              'isChecked': false,
            },
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Uncheck item abcdefgh…',
      );
    });

    test('falls back gracefully when resolver throws', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (_) async => throw Exception('DB error'),
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {
              'id': '12345678-abcd-ef01-2345-678901234567',
              'isChecked': true,
            },
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Check off item 12345678…',
      );
    });

    test('logs error via DomainLogger when resolver throws', () async {
      final mockLogger = MockDomainLogger();
      when(() => mockLogger.enabledDomains).thenReturn({'agent_workflow'});
      when(
        () => mockLogger.error(
          any(),
          any(),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenReturn(null);

      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        domainLogger: mockLogger,
        checklistItemStateResolver: (_) => throw Exception('connection lost'),
      );

      await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-err', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      // Verify logger was called with the error.
      verify(
        () => mockLogger.error(
          'agent_workflow',
          any(that: contains('failed to resolve checklist item state')),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);

      // Should still produce a fallback summary.
      expect(resolverBuilder.items, hasLength(1));
      expect(
        resolverBuilder.items.first.humanSummary,
        'Check off item item-err',
      );
    });

    test('handles uncheck update', () async {
      await builder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-7', 'isChecked': false},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(builder.items.first.humanSummary, 'Uncheck item item-7');
    });

    test('falls back to single item for unknown batch tool', () async {
      await builder.addBatchItem(
        toolName: 'unknown_batch_tool',
        args: {
          'items': [1, 2, 3]
        },
        summaryPrefix: 'Unknown',
      );

      expect(builder.items, hasLength(1));
      expect(builder.items.first.toolName, 'unknown_batch_tool');
      expect(builder.items.first.humanSummary, 'Unknown (batch)');
    });

    test('handles empty array gracefully', () async {
      await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {'items': <dynamic>[]},
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, hasLength(1));
      expect(builder.items.first.humanSummary, 'Checklist (empty)');
    });

    test('handles missing array key gracefully', () async {
      await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {'wrong_key': 'value'},
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, hasLength(1));
      expect(builder.items.first.humanSummary, 'Checklist (empty)');
    });
  });

  group('hasItems', () {
    test('returns false when no items added', () {
      expect(builder.hasItems, isFalse);
    });

    test('returns true after adding an item', () {
      builder.addItem(
        toolName: 'test',
        args: {},
        humanSummary: 'test',
      );
      expect(builder.hasItems, isTrue);
    });
  });

  group('build', () {
    test('returns null when no items', () async {
      final result = await builder.build(mockSyncService);
      expect(result, isNull);
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('builds and persists change set entity', () async {
      builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      final result = await builder.build(mockSyncService);

      expect(result, isNotNull);
      expect(result!.agentId, 'agent-001');
      expect(result.taskId, 'task-001');
      expect(result.threadId, 'thread-001');
      expect(result.runKey, 'run-key-001');
      expect(result.status, ChangeSetStatus.pending);
      expect(result.items, hasLength(1));
      expect(result.vectorClock, isNull);

      // Verify it was persisted.
      final captured =
          verify(() => mockSyncService.upsertEntity(captureAny())).captured;
      expect(captured, hasLength(1));
      expect(captured.first, isA<ChangeSetEntity>());
    });

    test('builds entity with exploded batch items', () async {
      await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'Item A'},
            {'title': 'Item B'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      final result = await builder.build(mockSyncService);

      expect(result, isNotNull);
      expect(result!.items, hasLength(2));
      expect(result.items[0].toolName, 'add_checklist_item');
      expect(result.items[1].toolName, 'add_checklist_item');
    });

    test('drops items that already exist in pending change sets', () async {
      builder
        ..addItem(
          toolName: 'set_task_title',
          args: {'title': 'Fix bug'},
          humanSummary: 'Set title to "Fix bug"',
        )
        ..addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 120},
          humanSummary: 'Set estimate to 2 hours',
        );

      final existingPending = [
        const ChangeItem(
          toolName: 'set_task_title',
          args: {'title': 'Fix bug'},
          humanSummary: 'Different summary, same change',
        ),
      ];

      final result = await builder.build(
        mockSyncService,
        existingPendingItems: existingPending,
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
      expect(result.items.first.toolName, 'update_task_estimate');
    });

    test('returns null when all items are duplicates', () async {
      builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );

      final existingPending = [
        const ChangeItem(
          toolName: 'set_task_title',
          args: {'title': 'Fix bug'},
          humanSummary: 'Already proposed',
        ),
      ];

      final result = await builder.build(
        mockSyncService,
        existingPendingItems: existingPending,
      );

      expect(result, isNull);
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('keeps items when args differ from existing pending', () async {
      builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      final existingPending = [
        const ChangeItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 60},
          humanSummary: 'Set estimate to 1 hour',
        ),
      ];

      final result = await builder.build(
        mockSyncService,
        existingPendingItems: existingPending,
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
      expect(result.items.first.args['minutes'], 120);
    });

    test('dedupes with deep map equality in args', () async {
      builder.addItem(
        toolName: 'add_checklist_item',
        args: {
          'title': 'Design mockup',
          'metadata': {'priority': 'high'},
        },
        humanSummary: 'Add checklist item',
      );

      final existingPending = [
        const ChangeItem(
          toolName: 'add_checklist_item',
          args: {
            'title': 'Design mockup',
            'metadata': {'priority': 'high'},
          },
          humanSummary: 'Already proposed',
        ),
      ];

      final result = await builder.build(
        mockSyncService,
        existingPendingItems: existingPending,
      );

      expect(result, isNull);
    });

    test('does not dedupe when existing items list is empty', () async {
      builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingItems: [],
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
    });
  });

  group('addBatchItem redundancy filtering', () {
    test('suppresses redundant check when item is already checked', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Buy groceries', isChecked: true),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, isEmpty);
      expect(result.added, 0);
      expect(result.redundant, 1);
      expect(result.redundantDetails, hasLength(1));
      expect(
        result.redundantDetails.first,
        contains('"Buy groceries" is already checked'),
      );
    });

    test('suppresses redundant uncheck when item is already unchecked',
        () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Write tests', isChecked: false),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-2', 'isChecked': false},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, isEmpty);
      expect(result.redundant, 1);
      expect(
        result.redundantDetails.first,
        contains('"Write tests" is already unchecked'),
      );
    });

    test('allows non-redundant check update to pass through', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Deploy app', isChecked: false),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-3', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test('mixed batch: some items redundant, some not', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async {
          if (id == 'item-a') return (title: 'Already done', isChecked: true);
          if (id == 'item-b') return (title: 'Not done', isChecked: false);
          return null;
        },
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-a', 'isChecked': true}, // redundant
            {'id': 'item-b', 'isChecked': true}, // not redundant
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(resolverBuilder.items.first.args['id'], 'item-b');
      expect(result.added, 1);
      expect(result.redundant, 1);
    });

    test('title-only update is NOT suppressed even when isChecked matches',
        () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Old title', isChecked: true),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'title': 'New title'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test('title change with redundant isChecked is NOT suppressed', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Old title', isChecked: true),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'isChecked': true, 'title': 'New title'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test('keeps item when resolver returns null (item not found)', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (_) async => null,
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-unknown', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test('keeps item when resolver throws (conservative)', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (_) async => throw Exception('DB error'),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'update_checklist_items',
        args: {
          'items': [
            {'id': 'item-err', 'isChecked': true},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test('does not filter add_checklist_item (only updates)', () async {
      final resolverBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        checklistItemStateResolver: (id) async =>
            (title: 'Existing item', isChecked: true),
      );

      final result = await resolverBuilder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'New item'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(resolverBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });
  });
}
