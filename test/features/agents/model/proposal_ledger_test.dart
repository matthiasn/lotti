import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';

import '../test_utils.dart';

void main() {
  group('ProposalLedger.isEmpty', () {
    test('is true for the empty constructor', () {
      const ledger = ProposalLedger.empty();
      expect(ledger.isEmpty, isTrue);
    });

    test('is true when both open and resolved are empty lists', () {
      const ledger = ProposalLedger(open: [], resolved: []);
      expect(ledger.isEmpty, isTrue);
    });

    test('is false when open has entries', () {
      final entry = makeLedgerEntry();
      final ledger = ProposalLedger(
        open: [entry],
        resolved: const [],
      );
      expect(ledger.isEmpty, isFalse);
    });

    test('is false when resolved has entries', () {
      final entry = makeLedgerEntry(status: ChangeItemStatus.confirmed);
      final ledger = ProposalLedger(
        open: const [],
        resolved: [entry],
      );
      expect(ledger.isEmpty, isFalse);
    });

    test('is false when both open and resolved are non-empty', () {
      final openEntry = makeLedgerEntry();
      final resolvedEntry = makeLedgerEntry(status: ChangeItemStatus.rejected);
      final ledger = ProposalLedger(
        open: [openEntry],
        resolved: [resolvedEntry],
      );
      expect(ledger.isEmpty, isFalse);
    });
  });

  group('LedgerEntry fields', () {
    test('optional fields default to null', () {
      final entry = makeLedgerEntry();
      expect(entry.resolvedAt, isNull);
      expect(entry.resolvedBy, isNull);
      expect(entry.verdict, isNull);
      expect(entry.reason, isNull);
    });

    test('optional fields accept non-null values', () {
      final entry = LedgerEntry(
        changeSetId: 'cs-002',
        itemIndex: 1,
        toolName: 'set_task_status',
        args: const <String, dynamic>{'status': 'DONE'},
        humanSummary: 'Mark as done',
        fingerprint: 'fp-xyz',
        status: ChangeItemStatus.confirmed,
        createdAt: DateTime(2024, 3, 15),
        resolvedAt: DateTime(2024, 3, 16),
        resolvedBy: DecisionActor.user,
        verdict: ChangeDecisionVerdict.confirmed,
        reason: 'User approved',
      );

      expect(entry.resolvedAt, equals(DateTime(2024, 3, 16)));
      expect(entry.resolvedBy, equals(DecisionActor.user));
      expect(entry.verdict, equals(ChangeDecisionVerdict.confirmed));
      expect(entry.reason, equals('User approved'));
    });
  });

  group('sticky rejection keys', () {
    // Read twice per wake — once per incremental change-set flush, once for
    // the end-of-wake write — so the derivation lives on the ledger rather
    // than at each call site.

    test('collects only rejected verdicts, ignoring other outcomes', () {
      final ledger = ProposalLedger(
        open: const [],
        resolved: [
          makeLedgerEntry(
            fingerprint: 'fp-rejected',
            status: ChangeItemStatus.rejected,
            verdict: ChangeDecisionVerdict.rejected,
          ),
          makeLedgerEntry(
            fingerprint: 'fp-confirmed',
            status: ChangeItemStatus.confirmed,
            verdict: ChangeDecisionVerdict.confirmed,
          ),
          makeLedgerEntry(fingerprint: 'fp-open'),
        ],
      );

      expect(ledger.rejectedFingerprints, {'fp-rejected'});
    });

    test('a rejection under a retired tool name also blocks its successor', () {
      // The wake proposes `update_time_entry {entryId}` today; the user turned
      // this very text down while it was still `update_running_timer
      // {timerId}`, and that must not come back once.
      final ledger = ProposalLedger(
        open: const [],
        resolved: [
          makeLedgerEntry(
            toolName: 'update_running_timer',
            args: const {'timerId': 'timer-1', 'summary': 'Focus block'},
            fingerprint: 'fp-legacy',
            verdict: ChangeDecisionVerdict.rejected,
          ),
        ],
      );

      expect(ledger.rejectedFingerprints, {
        'fp-legacy',
        ChangeItem.fingerprintFromParts('update_time_entry', const {
          'entryId': 'timer-1',
          'summary': 'Focus block',
        }),
      });
    });

    test('keys rejected summaries so a reworded re-proposal still blocks', () {
      final ledger = ProposalLedger(
        open: const [],
        resolved: [
          makeLedgerEntry(
            toolName: 'add_checklist_item',
            args: const {'title': 'Ship the release'},
            humanSummary: 'Add "Ship the release"',
            verdict: ChangeDecisionVerdict.rejected,
          ),
        ],
      );

      expect(
        ledger.rejectedDisplayKeys,
        equals({
          ChangeItem.displayDuplicateKeyFromParts(
            'add_checklist_item',
            'Add "Ship the release"',
            args: const {'title': 'Ship the release'},
          ),
        }),
      );
    });

    test('both are empty for a ledger with nothing rejected', () {
      const ledger = ProposalLedger.empty();
      expect(ledger.rejectedFingerprints, isEmpty);
      expect(ledger.rejectedDisplayKeys, isEmpty);
    });
  });
}
