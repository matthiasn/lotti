import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../test_utils.dart';

void main() {
  group('ChangeProposalFilter.formatBatchResponse', () {
    test('formats clean batch with only added items', () {
      const result = BatchAddResult(added: 3, skipped: 0);
      expect(
        ChangeProposalFilter.formatBatchResponse(result),
        'Proposal queued for user review (3 item(s) queued).',
      );
    });

    test('includes skipped count when present', () {
      const result = BatchAddResult(added: 1, skipped: 2);
      final response = ChangeProposalFilter.formatBatchResponse(result);
      expect(response, contains('1 item(s) queued'));
      expect(response, contains('2 malformed item(s) skipped'));
    });

    test('includes redundant info when present', () {
      const result = BatchAddResult(
        added: 1,
        skipped: 0,
        redundant: 2,
        redundantDetails: [
          '"Buy groceries" is already checked',
          '"Walk dog" is already checked',
        ],
      );
      final response = ChangeProposalFilter.formatBatchResponse(result);
      expect(response, contains('1 item(s) queued'));
      expect(response, contains('Skipped 2 redundant update(s)'));
      expect(response, contains('"Buy groceries" is already checked'));
      expect(response, contains('"Walk dog" is already checked'));
    });

    test('shows all categories when skipped and redundant both present', () {
      const result = BatchAddResult(
        added: 1,
        skipped: 1,
        redundant: 1,
        redundantDetails: ['"Done item" is already checked'],
      );
      final response = ChangeProposalFilter.formatBatchResponse(result);
      expect(response, contains('1 item(s) queued'));
      expect(response, contains('1 malformed item(s) skipped'));
      expect(response, contains('Skipped 1 redundant update(s)'));
    });

    test('shows queued message when zero added but no skipped or redundant',
        () {
      const result = BatchAddResult(added: 0, skipped: 0);
      expect(
        ChangeProposalFilter.formatBatchResponse(result),
        'Proposal queued for user review (0 item(s) queued).',
      );
    });

    test('omits queued line when zero added but has skipped', () {
      const result = BatchAddResult(added: 0, skipped: 3);
      final response = ChangeProposalFilter.formatBatchResponse(result);
      expect(response, isNot(contains('queued')));
      expect(response, contains('3 malformed item(s) skipped'));
    });

    test('omits queued line when zero added but has redundant', () {
      const result = BatchAddResult(
        added: 0,
        skipped: 0,
        redundant: 2,
        redundantDetails: ['a', 'b'],
      );
      final response = ChangeProposalFilter.formatBatchResponse(result);
      expect(response, isNot(contains('queued')));
      expect(response, contains('Skipped 2 redundant update(s)'));
    });
  });

  group('ChangeProposalFilter.checkTaskMetadataRedundancy', () {
    const baseSnapshot = kTestTaskMetadataSnapshot;

    group('update_task_estimate', () {
      test('returns skip message when estimate matches', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_estimate',
          {'minutes': 120},
          baseSnapshot,
        );
        expect(result, 'Skipped: estimate is already 120 minutes.');
      });

      test('returns null when estimate differs', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_estimate',
          {'minutes': 60},
          baseSnapshot,
        );
        expect(result, isNull);
      });

      test('returns null when current estimate is null', () {
        const snapshot = (
          title: 'Test',
          status: 'OPEN',
          priority: 'P2',
          estimateMinutes: null as int?,
          dueDate: null as String?,
        );
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_estimate',
          {'minutes': 60},
          snapshot,
        );
        expect(result, isNull);
      });

      test('returns null when minutes arg is not int', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_estimate',
          {'minutes': '120'},
          baseSnapshot,
        );
        expect(result, isNull);
      });
    });

    group('update_task_priority', () {
      test('returns skip message when priority matches', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_priority',
          {'priority': 'P1'},
          baseSnapshot,
        );
        expect(result, 'Skipped: priority is already P1.');
      });

      test('returns null when priority differs', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_priority',
          {'priority': 'P2'},
          baseSnapshot,
        );
        expect(result, isNull);
      });

      test('returns null when current priority is null', () {
        const snapshot = (
          title: 'Test',
          status: 'OPEN',
          priority: null as String?,
          estimateMinutes: null as int?,
          dueDate: null as String?,
        );
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_priority',
          {'priority': 'P1'},
          snapshot,
        );
        expect(result, isNull);
      });
    });

    group('update_task_due_date', () {
      test('returns skip message when due date matches', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_due_date',
          {'dueDate': '2026-03-15'},
          baseSnapshot,
        );
        expect(result, 'Skipped: due date is already 2026-03-15.');
      });

      test('returns null when due date differs', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_due_date',
          {'dueDate': '2026-04-01'},
          baseSnapshot,
        );
        expect(result, isNull);
      });

      test('returns null when current due date is null', () {
        const snapshot = (
          title: 'Test',
          status: 'OPEN',
          priority: 'P2',
          estimateMinutes: null as int?,
          dueDate: null as String?,
        );
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'update_task_due_date',
          {'dueDate': '2026-03-15'},
          snapshot,
        );
        expect(result, isNull);
      });
    });

    group('set_task_status', () {
      test('returns skip message when status matches', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'set_task_status',
          {'status': 'IN PROGRESS'},
          baseSnapshot,
        );
        expect(result, 'Skipped: status is already IN PROGRESS.');
      });

      test('returns null when status differs', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'set_task_status',
          {'status': 'GROOMED'},
          baseSnapshot,
        );
        expect(result, isNull);
      });
    });

    group('set_task_title', () {
      test('returns skip message when title matches', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'set_task_title',
          {'title': 'Fix login bug'},
          baseSnapshot,
        );
        expect(result, 'Skipped: title is already "Fix login bug".');
      });

      test('returns null when title differs', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'set_task_title',
          {'title': 'New title'},
          baseSnapshot,
        );
        expect(result, isNull);
      });
    });

    group('unknown tools', () {
      test('returns null for unknown tool names', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'unknown_tool',
          {'key': 'value'},
          baseSnapshot,
        );
        expect(result, isNull);
      });

      test('returns null for assign_task_labels (no redundancy check)', () {
        final result = ChangeProposalFilter.checkTaskMetadataRedundancy(
          'assign_task_labels',
          {
            'labels': [
              {'id': 'l1'},
            ],
          },
          baseSnapshot,
        );
        expect(result, isNull);
      });
    });
  });

  group('ChangeProposalFilter.resolveTaskMetadata', () {
    late MockJournalDb mockDb;

    setUp(() {
      mockDb = MockJournalDb();
    });

    test('builds snapshot from a Task entity', () async {
      final task = Task(
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime(2026, 3),
            utcOffset: 60,
          ),
          title: 'Fix login bug',
          statusHistory: [],
          dateTo: DateTime(2026, 3),
          dateFrom: DateTime(2026, 3),
          estimate: const Duration(hours: 2),
          due: DateTime(2026, 3, 15),
          priority: TaskPriority.p1High,
        ),
        meta: testTask.meta,
        entryText: testTask.entryText,
      );
      when(() => mockDb.journalEntityById('task-1'))
          .thenAnswer((_) async => task);

      final snapshot = await ChangeProposalFilter.resolveTaskMetadata(
        mockDb,
        'task-1',
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.title, 'Fix login bug');
      expect(snapshot.status, 'OPEN');
      expect(snapshot.priority, 'P1');
      expect(snapshot.estimateMinutes, 120);
      expect(snapshot.dueDate, '2026-03-15');
    });

    test('returns null for non-Task entity', () async {
      when(() => mockDb.journalEntityById('entry-1'))
          .thenAnswer((_) async => testTextEntry);

      final snapshot = await ChangeProposalFilter.resolveTaskMetadata(
        mockDb,
        'entry-1',
      );

      expect(snapshot, isNull);
    });

    test('returns null when entity is not found', () async {
      when(() => mockDb.journalEntityById('missing'))
          .thenAnswer((_) async => null);

      final snapshot = await ChangeProposalFilter.resolveTaskMetadata(
        mockDb,
        'missing',
      );

      expect(snapshot, isNull);
    });

    test('handles task with null optional fields', () async {
      final task = Task(
        data: TaskData(
          status: TaskStatus.inProgress(
            id: 'status-2',
            createdAt: DateTime(2026, 3),
            utcOffset: 60,
          ),
          title: 'Minimal task',
          statusHistory: [],
          dateTo: DateTime(2026, 3),
          dateFrom: DateTime(2026, 3),
        ),
        meta: testTask.meta,
        entryText: testTask.entryText,
      );
      when(() => mockDb.journalEntityById('task-2'))
          .thenAnswer((_) async => task);

      final snapshot = await ChangeProposalFilter.resolveTaskMetadata(
        mockDb,
        'task-2',
      );

      expect(snapshot, isNotNull);
      expect(snapshot!.title, 'Minimal task');
      expect(snapshot.status, 'IN PROGRESS');
      expect(snapshot.priority, 'P2'); // default
      expect(snapshot.estimateMinutes, isNull);
      expect(snapshot.dueDate, isNull);
    });
  });
}
