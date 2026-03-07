import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late ChangeSetBuilder builder;
  late MockAgentSyncService mockSyncService;
  late MockAgentRepository mockRepository;

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
    mockRepository = MockAgentRepository();
    builder = ChangeSetBuilder(
      agentId: 'agent-001',
      taskId: 'task-001',
      threadId: 'thread-001',
      runKey: 'run-key-001',
    );

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.repository).thenReturn(mockRepository);

    // Default: getEntity returns null so build() falls back to the
    // passed-in entity.
    when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
  });

  group('addItem', () {
    test('adds a single item to the builder', () async {
      await builder.addItem(
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

    test('accumulates multiple items in order', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );
      await builder.addItem(
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
    test(
      'explodes add_multiple_checklist_items into individual items',
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
      },
    );

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

    test(
      'handles check-only update (no title) by ID with truncated ID',
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
      },
    );

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
          'items': [1, 2, 3],
        },
        summaryPrefix: 'Unknown',
      );

      expect(builder.items, hasLength(1));
      expect(builder.items.first.toolName, 'unknown_batch_tool');
      expect(builder.items.first.humanSummary, 'Unknown (batch)');
    });

    test('handles empty array without queuing a placeholder', () async {
      final result = await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {'items': <dynamic>[]},
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, isEmpty);
      expect(result.added, 0);
    });

    test('handles missing array key without queuing a placeholder', () async {
      final result = await builder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {'wrong_key': 'value'},
        summaryPrefix: 'Checklist',
      );

      expect(builder.items, isEmpty);
      expect(result.added, 0);
    });
  });

  group('addBatchItem — label explosion', () {
    test(
      'explodes assign_task_labels into individual assign_task_label items',
      () async {
        final result = await builder.addBatchItem(
          toolName: 'assign_task_labels',
          args: {
            'labels': [
              {'id': 'label-1', 'confidence': 'high'},
              {'id': 'label-2', 'confidence': 'medium'},
            ],
          },
          summaryPrefix: 'Label',
        );

        expect(result.added, 2);
        expect(result.skipped, 0);
        expect(result.redundant, 0);
        expect(builder.items, hasLength(2));
        expect(builder.items[0].toolName, 'assign_task_label');
        expect(builder.items[0].args, {'id': 'label-1', 'confidence': 'high'});
        expect(builder.items[1].toolName, 'assign_task_label');
        expect(builder.items[1].args, {
          'id': 'label-2',
          'confidence': 'medium',
        });
      },
    );

    test('generates human-readable summaries with label names', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        labelNameResolver: (labelId) async {
          return switch (labelId) {
            'label-1' => 'Bug',
            'label-2' => 'Backend',
            _ => null,
          };
        },
      );

      await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'high'},
            {'id': 'label-2', 'confidence': 'medium'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(
        builderWithResolver.items[0].humanSummary,
        'Assign label: "Bug" (high)',
      );
      expect(
        builderWithResolver.items[1].humanSummary,
        'Assign label: "Backend" (medium)',
      );
    });

    test('generates summary with truncated ID when no resolver', () async {
      await builder.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'abcdefgh-1234-5678', 'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(
        builder.items[0].humanSummary,
        contains('Assign label:'),
      );
      expect(
        builder.items[0].humanSummary,
        contains('abcdefgh'),
      );
    });

    test('filters out labels already assigned to the task', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingLabelIdsResolver: () async => {'label-1'},
        labelNameResolver: (id) async => 'Label $id',
      );

      final result = await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'high'},
            {'id': 'label-2', 'confidence': 'medium'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(result.added, 1);
      expect(result.redundant, 1);
      expect(result.redundantDetails, hasLength(1));
      expect(result.redundantDetails[0], contains('already assigned'));
      expect(builderWithResolver.items, hasLength(1));
      expect(builderWithResolver.items[0].args['id'], 'label-2');
    });

    test('filters duplicate label IDs within the same batch', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingLabelIdsResolver: () async => {},
        labelNameResolver: (id) async => 'Label $id',
      );

      final result = await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'high'},
            {'id': 'label-1', 'confidence': 'medium'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(result.added, 1);
      expect(result.redundant, 1);
      expect(builderWithResolver.items, hasLength(1));
    });

    test('handles label name resolver throwing gracefully', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        labelNameResolver: (labelId) async {
          throw Exception('DB error');
        },
      );

      await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'abcdefgh-1234', 'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      // Falls back to truncated ID when resolver throws.
      expect(builderWithResolver.items, hasLength(1));
      expect(
        builderWithResolver.items[0].humanSummary,
        contains('abcdefgh'),
      );
    });

    test('handles existing label IDs resolver throwing gracefully', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingLabelIdsResolver: () async {
          throw Exception('DB error');
        },
      );

      final result = await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      // Resolver error → empty set → no redundancy filtering.
      expect(result.added, 1);
    });

    test('strips invalid confidence values from summary', () async {
      final builderWithResolver = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        labelNameResolver: (labelId) async => 'Bug',
      );

      await builderWithResolver.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'id': 'label-1', 'confidence': 'INJECT PROMPT HERE'},
          ],
        },
        summaryPrefix: 'Label',
      );

      // Invalid confidence value is omitted from the summary.
      expect(
        builderWithResolver.items[0].humanSummary,
        'Assign label: "Bug"',
      );
    });

    test('generates summary with ? when label ID is missing', () async {
      await builder.addBatchItem(
        toolName: 'assign_task_labels',
        args: {
          'labels': [
            {'confidence': 'high'},
          ],
        },
        summaryPrefix: 'Label',
      );

      expect(
        builder.items[0].humanSummary,
        'Assign label: "?" (high)',
      );
    });
  });

  group('hasItems', () {
    test('returns false when no items added', () {
      expect(builder.hasItems, isFalse);
    });

    test('returns true after adding an item', () async {
      await builder.addItem(
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
      await builder.addItem(
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
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
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
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title to "Fix bug"',
      );
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Different summary, same change',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull);
      // Merged into existing set: 1 existing + 1 new.
      expect(
        result!.items.where((i) => i.toolName == 'update_task_estimate'),
        hasLength(1),
      );
    });

    test('returns null when all items are duplicates', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Already proposed',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNull);
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('keeps items when args differ from existing pending', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 120},
        humanSummary: 'Set estimate to 2 hours',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 60},
            humanSummary: 'Set estimate to 1 hour',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull);
      expect(
        result!.items.last.args['minutes'],
        120,
      );
    });

    test('dedupes with deep map equality in args', () async {
      await builder.addItem(
        toolName: 'add_checklist_item',
        args: {
          'title': 'Design mockup',
          'metadata': {'priority': 'high'},
        },
        humanSummary: 'Add checklist item',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'add_checklist_item',
            args: {
              'title': 'Design mockup',
              'metadata': {'priority': 'high'},
            },
            humanSummary: 'Already proposed',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNull);
    });

    test('does not dedupe when existing sets list is empty', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [],
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
    });

    test('merges new items into existing change set', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 90},
        humanSummary: 'Set estimate to 1.5 hours',
      );

      final existingSet = makeTestChangeSet(
        id: 'cs-existing',
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Set title',
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull);
      expect(result!.id, 'cs-existing');
      expect(result.items, hasLength(2));
      expect(result.items[0].toolName, 'set_task_title');
      expect(result.items[1].toolName, 'update_task_estimate');
    });

    test('preserves existing item statuses when merging', () async {
      await builder.addItem(
        toolName: 'update_task_estimate',
        args: {'minutes': 90},
        humanSummary: 'Set estimate',
      );

      final existingSet = makeTestChangeSet(
        id: 'cs-existing',
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Set title',
            status: ChangeItemStatus.confirmed,
          ),
          ChangeItem(
            toolName: 'set_task_status',
            args: {'status': 'IN_PROGRESS'},
            humanSummary: 'Set status',
            status: ChangeItemStatus.rejected,
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(3));
      expect(result.items[0].status, ChangeItemStatus.confirmed);
      expect(result.items[1].status, ChangeItemStatus.rejected);
      expect(result.items[2].status, ChangeItemStatus.pending);
    });

    test('blocks re-proposal of rejected items', () async {
      // The agent proposes the exact same mutation that was already rejected.
      await builder.addItem(
        toolName: 'update_checklist_item',
        args: {'id': 'item-1', 'isChecked': true},
        humanSummary: 'Check off: "Buy milk"',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_checklist_item',
            args: {'id': 'item-1', 'isChecked': true},
            humanSummary: 'Check off: "Buy milk"',
            status: ChangeItemStatus.rejected,
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNull, reason: 'rejected items must not be re-proposed');
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('blocks re-proposal of deferred items', () async {
      await builder.addItem(
        toolName: 'set_task_status',
        args: {'status': 'IN_PROGRESS'},
        humanSummary: 'Set status',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'set_task_status',
            args: {'status': 'IN_PROGRESS'},
            humanSummary: 'Set status',
            status: ChangeItemStatus.deferred,
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNull, reason: 'deferred items must not be re-proposed');
    });

    test(
      'allows proposal when same tool has different args than rejected',
      () async {
        // The agent proposes a different value than what was rejected.
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 60},
          humanSummary: 'Set estimate to 1 hour',
        );

        final existingSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 120},
              humanSummary: 'Set estimate to 2 hours',
              status: ChangeItemStatus.rejected,
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [existingSet],
        );

        expect(
          result,
          isNotNull,
          reason: 'different args should not be blocked',
        );
      },
    );

    test('skips confirmed items during dedup (already applied)', () async {
      // The agent proposes the same mutation that was already confirmed.
      // Confirmed items have been applied — re-proposing is a no-op but
      // should not be blocked by dedup (the redundancy filter catches this
      // at the checklist-item level instead).
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'Fix bug'},
        humanSummary: 'Set title',
      );

      final existingSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Set title',
            status: ChangeItemStatus.confirmed,
          ),
        ],
      );

      final result = await builder.build(
        mockSyncService,
        existingPendingSets: [existingSet],
      );

      expect(result, isNotNull, reason: 'confirmed items are not in dedup set');
    });

    test('creates new entity when no existing pending set', () async {
      await builder.addItem(
        toolName: 'set_task_title',
        args: {'title': 'New task'},
        humanSummary: 'Set title',
      );

      final result = await builder.build(mockSyncService);

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
      expect(result.agentId, 'agent-001');
      expect(result.taskId, 'task-001');
      verify(() => mockSyncService.upsertEntity(any())).called(1);
    });

    test(
      'consolidates multiple existing sets into one and resolves surplus',
      () async {
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 45},
          humanSummary: 'Set estimate to 45 min',
        );

        // Two racing sets with some overlapping items.
        final older = makeTestChangeSet(
          id: 'cs-older',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Fix bug'},
              humanSummary: 'Set title',
            ),
          ],
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer',
          createdAt: DateTime(2024, 3, 15, 11),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Fix bug'},
              humanSummary: 'Set title',
            ),
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'IN_PROGRESS'},
              humanSummary: 'Set status',
            ),
          ],
        );

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [older, newer],
        );

        expect(result, isNotNull);
        // Survivor is the newer set. It keeps its own items + new items.
        // The older set's title item is a duplicate (already in newer) so
        // it's not added again.
        expect(result!.id, 'cs-newer');
        expect(result.items, hasLength(3));
        expect(result.items[0].toolName, 'set_task_title');
        expect(result.items[1].toolName, 'set_task_status');
        expect(result.items[2].toolName, 'update_task_estimate');

        // Verify: survivor updated + older marked as resolved = 2 upserts.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(captured, hasLength(2));

        // First upsert: the consolidated survivor.
        final survivor = captured[0] as ChangeSetEntity;
        expect(survivor.id, 'cs-newer');
        expect(survivor.items, hasLength(3));

        // Second upsert: the surplus set marked as resolved.
        final resolved = captured[1] as ChangeSetEntity;
        expect(resolved.id, 'cs-older');
        expect(resolved.status, ChangeSetStatus.resolved);
        expect(resolved.resolvedAt, isNotNull);
      },
    );

    test(
      'build uses fresh items from DB, not stale snapshot',
      () async {
        await builder.addItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 90},
          humanSummary: 'Set estimate to 90 min',
        );

        // The stale snapshot passed to build() has both items pending.
        final staleSet = makeTestChangeSet(
          id: 'cs-stale',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Old title'},
              humanSummary: 'Set title',
            ),
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'OPEN'},
              humanSummary: 'Set status',
            ),
          ],
        );

        // Simulate a mid-wake confirmation: the DB has item 0 confirmed.
        final freshSet = staleSet.copyWith(
          items: [
            staleSet.items[0].copyWith(status: ChangeItemStatus.confirmed),
            staleSet.items[1],
          ],
          status: ChangeSetStatus.partiallyResolved,
        );

        when(
          () => mockRepository.getEntity('cs-stale'),
        ).thenAnswer((_) async => freshSet);

        final result = await builder.build(
          mockSyncService,
          existingPendingSets: [staleSet],
        );

        expect(result, isNotNull);

        // The merged set should use the fresh items (with confirmed status)
        // not the stale snapshot's items.
        final confirmedItems = result!.items
            .where((i) => i.status == ChangeItemStatus.confirmed)
            .toList();
        expect(
          confirmedItems,
          hasLength(1),
          reason: 'Mid-wake confirmation should be preserved',
        );
        expect(confirmedItems.first.args, {'title': 'Old title'});

        // The new item should still be appended.
        expect(
          result.items.last.toolName,
          'update_task_estimate',
        );
      },
    );
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

    test(
      'suppresses redundant uncheck when item is already unchecked',
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
      },
    );

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

    test(
      'title-only update is NOT suppressed even when isChecked matches',
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
      },
    );

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

    test(
      'keeps item when resolver returns isChecked as null (conservative)',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Ambiguous item', isChecked: null),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-null', 'isChecked': true},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(resolverBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 0);
      },
    );

    test(
      'suppresses when both isChecked and title match current state',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Same title', isChecked: true),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-both', 'isChecked': true, 'title': 'Same title'},
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(resolverBuilder.items, isEmpty);
        expect(result.added, 0);
        expect(result.redundant, 1);
        expect(
          result.redundantDetails.first,
          contains('"Same title" is already checked'),
        );
      },
    );

    test(
      'keeps update with empty title string (treated as malformed)',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Some item', isChecked: true),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-y', 'title': ''}, // Empty title — malformed
            ],
          },
          summaryPrefix: 'Checklist',
        );

        // Empty title is not a valid proposal — kept defensively.
        expect(resolverBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 0);
      },
    );

    test(
      'keeps malformed update with only id (no isChecked, no title)',
      () async {
        final resolverBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          checklistItemStateResolver: (id) async =>
              (title: 'Some item', isChecked: true),
        );

        final result = await resolverBuilder.addBatchItem(
          toolName: 'update_checklist_items',
          args: {
            'items': [
              {'id': 'item-x'}, // No isChecked, no title — malformed
            ],
          },
          summaryPrefix: 'Checklist',
        );

        // Malformed proposals are kept defensively.
        expect(resolverBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 0);
      },
    );

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

  group('add_checklist_item title-based dedup', () {
    test(
      'suppresses add when title already exists (case-insensitive)',
      () async {
        final titledBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          existingChecklistTitlesResolver: () async => {
            'buy groceries',
            'write tests',
          },
        );

        final result = await titledBuilder.addBatchItem(
          toolName: 'add_multiple_checklist_items',
          args: {
            'items': [
              {'title': 'Buy Groceries'}, // exists (case-insensitive)
              {'title': 'Deploy app'}, // novel
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(titledBuilder.items, hasLength(1));
        expect(titledBuilder.items.first.args['title'], 'Deploy app');
        expect(result.added, 1);
        expect(result.redundant, 1);
        expect(
          result.redundantDetails.first,
          contains('"Buy Groceries" already exists on the task'),
        );
      },
    );

    test('allows add when title is novel', () async {
      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async => {
          'buy groceries',
          'write tests',
        },
      );

      final result = await titledBuilder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'Deploy to production'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      expect(titledBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });

    test(
      'same-wake dedup: second add with same title in batch is suppressed',
      () async {
        final titledBuilder = ChangeSetBuilder(
          agentId: 'agent-001',
          taskId: 'task-001',
          threadId: 'thread-001',
          runKey: 'run-key-001',
          existingChecklistTitlesResolver: () async => <String>{},
        );

        final result = await titledBuilder.addBatchItem(
          toolName: 'add_multiple_checklist_items',
          args: {
            'items': [
              {'title': 'Write tests'},
              {'title': 'write tests'}, // same title, different case
            ],
          },
          summaryPrefix: 'Checklist',
        );

        expect(titledBuilder.items, hasLength(1));
        expect(result.added, 1);
        expect(result.redundant, 1);
      },
    );

    test('addItem suppresses add_checklist_item when title exists', () async {
      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async => {'buy milk'},
      );

      final redundancy = await titledBuilder.addItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Buy Milk'},
        humanSummary: 'Add: "Buy Milk"',
      );

      expect(redundancy, isNotNull);
      expect(redundancy, contains('"Buy Milk" already exists'));
      expect(titledBuilder.items, isEmpty);
    });

    test('addItem allows novel add_checklist_item', () async {
      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async => {'buy milk'},
      );

      final redundancy = await titledBuilder.addItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Write docs'},
        humanSummary: 'Add: "Write docs"',
      );

      expect(redundancy, isNull);
      expect(titledBuilder.items, hasLength(1));
    });

    test('gracefully handles resolver failure', () async {
      final titledBuilder = ChangeSetBuilder(
        agentId: 'agent-001',
        taskId: 'task-001',
        threadId: 'thread-001',
        runKey: 'run-key-001',
        existingChecklistTitlesResolver: () async =>
            throw Exception('DB error'),
      );

      final result = await titledBuilder.addBatchItem(
        toolName: 'add_multiple_checklist_items',
        args: {
          'items': [
            {'title': 'New item'},
          ],
        },
        summaryPrefix: 'Checklist',
      );

      // Should keep the item (conservative fallback).
      expect(titledBuilder.items, hasLength(1));
      expect(result.added, 1);
      expect(result.redundant, 0);
    });
  });

  group('rejected fingerprint dedup in build()', () {
    test('blocks re-proposal matching a rejected fingerprint', () async {
      await builder.addItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Buy milk'},
        humanSummary: 'Add: "Buy milk"',
      );

      // Reconstruct the fingerprint as the workflow would.
      final rejectedFp = ChangeItem.fingerprint(
        const ChangeItem(
          toolName: 'add_checklist_item',
          args: {'title': 'Buy milk'},
          humanSummary: '',
        ),
      );

      final result = await builder.build(
        mockSyncService,
        rejectedFingerprints: {rejectedFp},
      );

      expect(
        result,
        isNull,
        reason: 'item matching a rejected fingerprint must be blocked',
      );
    });

    test('allows item that does not match any rejected fingerprint', () async {
      await builder.addItem(
        toolName: 'add_checklist_item',
        args: {'title': 'Buy milk'},
        humanSummary: 'Add: "Buy milk"',
      );

      // Different args → different fingerprint.
      final rejectedFp = ChangeItem.fingerprint(
        const ChangeItem(
          toolName: 'add_checklist_item',
          args: {'title': 'Buy eggs'},
          humanSummary: '',
        ),
      );

      final result = await builder.build(
        mockSyncService,
        rejectedFingerprints: {rejectedFp},
      );

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
    });
  });

  group('task splitting — addFollowUpTask', () {
    test(
      'generates deterministic placeholder from sourceTaskId + title',
      () async {
        final placeholder1 = await builder.addFollowUpTask(
          args: {'title': 'Follow-Up A'},
          humanSummary: 'Create follow-up task A',
        );

        // Same source task and title should produce the same placeholder.
        final placeholder2 = ChangeSetBuilder.deterministicPlaceholder(
          'task-001',
          'Follow-Up A',
        );

        expect(placeholder1, placeholder2);
        expect(placeholder1, isNotEmpty);
      },
    );

    test('adds item with _placeholderTaskId in args', () async {
      final placeholder = await builder.addFollowUpTask(
        args: {'title': 'Follow-Up B'},
        humanSummary: 'Create follow-up task B',
      );

      expect(builder.items, hasLength(1));
      final item = builder.items.first;
      expect(item.toolName, 'create_follow_up_task');
      expect(item.args['title'], 'Follow-Up B');
      expect(item.args['_placeholderTaskId'], placeholder);
    });

    test('uses placeholder as default groupId', () async {
      final placeholder = await builder.addFollowUpTask(
        args: {'title': 'Follow-Up C'},
        humanSummary: 'Create follow-up task C',
      );

      expect(builder.items.first.groupId, placeholder);
    });

    test('uses provided groupId over default', () async {
      await builder.addFollowUpTask(
        args: {'title': 'Follow-Up D'},
        humanSummary: 'Create follow-up task D',
        groupId: 'custom-group',
      );

      expect(builder.items.first.groupId, 'custom-group');
    });

    test('deterministic placeholder is stable across wakes', () {
      // Two different builder instances with the same task ID should
      // produce the same placeholder for the same title.
      final builder2 = ChangeSetBuilder(
        agentId: 'agent-002',
        taskId: 'task-001',
        threadId: 'thread-002',
        runKey: 'run-key-002',
      );

      final p1 = ChangeSetBuilder.deterministicPlaceholder(
        'task-001',
        'Refactor login',
      );
      final p2 = ChangeSetBuilder.deterministicPlaceholder(
        builder2.taskId,
        'Refactor login',
      );

      expect(p1, p2);
    });

    test('different titles produce different placeholders', () {
      final p1 = ChangeSetBuilder.deterministicPlaceholder(
        'task-001',
        'Follow-Up A',
      );
      final p2 = ChangeSetBuilder.deterministicPlaceholder(
        'task-001',
        'Follow-Up B',
      );

      expect(p1, isNot(p2));
    });
  });

  group('task splitting — migrate batch explosion', () {
    test(
      'singularizes migrate_checklist_items to migrate_checklist_item',
      () async {
        final result = await builder.addBatchItem(
          toolName: 'migrate_checklist_items',
          args: {
            'items': [
              {'id': 'item-1', 'title': 'Buy milk'},
            ],
            'targetTaskId': 'target-001',
          },
          summaryPrefix: 'Migrate',
        );

        expect(result.added, 1);
        expect(builder.items.first.toolName, 'migrate_checklist_item');
      },
    );

    test('injects targetTaskId into each child element', () async {
      await builder.addBatchItem(
        toolName: 'migrate_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'title': 'Buy milk'},
            {'id': 'item-2', 'title': 'Walk dog'},
          ],
          'targetTaskId': 'target-task-xyz',
        },
        summaryPrefix: 'Migrate',
      );

      expect(builder.items, hasLength(2));
      for (final item in builder.items) {
        expect(item.args['targetTaskId'], 'target-task-xyz');
      }
    });

    test('assigns groupId to all exploded items', () async {
      await builder.addBatchItem(
        toolName: 'migrate_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'title': 'Item A'},
            {'id': 'item-2', 'title': 'Item B'},
          ],
          'targetTaskId': 'target-001',
        },
        summaryPrefix: 'Migrate',
        groupId: 'split-group-001',
      );

      expect(builder.items, hasLength(2));
      expect(builder.items[0].groupId, 'split-group-001');
      expect(builder.items[1].groupId, 'split-group-001');
    });

    test('handles missing targetTaskId gracefully', () async {
      await builder.addBatchItem(
        toolName: 'migrate_checklist_items',
        args: {
          'items': [
            {'id': 'item-1', 'title': 'Buy milk'},
          ],
        },
        summaryPrefix: 'Migrate',
      );

      // Item is still added, just without targetTaskId injection.
      expect(builder.items, hasLength(1));
      expect(builder.items.first.args.containsKey('targetTaskId'), isFalse);
    });
  });
}
