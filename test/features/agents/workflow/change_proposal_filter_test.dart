import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';

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
}
