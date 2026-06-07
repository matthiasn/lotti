import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';

import '../test_utils.dart';

// ── Generators ────────────────────────────────────────────────────────────────

extension _AnyChangeItemStatus on glados.Any {
  glados.Generator<ChangeItemStatus> get changeItemStatus =>
      glados.AnyUtils(this).choose(ChangeItemStatus.values);
}

void main() {
  group('LedgerEntry.isOpen', () {
    test('is true when status is pending', () {
      final entry = makeLedgerEntry();
      expect(entry.isOpen, isTrue);
    });

    test('is false when status is confirmed', () {
      final entry = makeLedgerEntry(status: ChangeItemStatus.confirmed);
      expect(entry.isOpen, isFalse);
    });

    test('is false when status is rejected', () {
      final entry = makeLedgerEntry(status: ChangeItemStatus.rejected);
      expect(entry.isOpen, isFalse);
    });

    test('is false when status is deferred', () {
      final entry = makeLedgerEntry(status: ChangeItemStatus.deferred);
      expect(entry.isOpen, isFalse);
    });

    test('is false when status is retracted', () {
      final entry = makeLedgerEntry(status: ChangeItemStatus.retracted);
      expect(entry.isOpen, isFalse);
    });

    glados.Glados(
      glados.any.changeItemStatus,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'isOpen is true if and only if status == pending',
      (status) {
        final entry = makeLedgerEntry(status: status);
        expect(
          entry.isOpen,
          equals(status == ChangeItemStatus.pending),
          reason: 'status=$status',
        );
      },
      tags: 'glados',
    );
  });

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
      expect(entry.groupId, isNull);
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
        groupId: 'group-1',
      );

      expect(entry.resolvedAt, equals(DateTime(2024, 3, 16)));
      expect(entry.resolvedBy, equals(DecisionActor.user));
      expect(entry.verdict, equals(ChangeDecisionVerdict.confirmed));
      expect(entry.reason, equals('User approved'));
      expect(entry.groupId, equals('group-1'));
    });
  });
}
