import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/journal_update_result.dart';

void main() {
  group('JournalUpdateResult.applied', () {
    test('defaults rowsWritten to 1 when omitted', () {
      final result = JournalUpdateResult.applied();

      expect(result.applied, isTrue);
      expect(result.rowsWritten, 1);
      expect(result.skipReason, isNull);
      expect(result.skipped, isFalse);
    });

    test('accepts custom rowsWritten', () {
      final result = JournalUpdateResult.applied(rowsWritten: 3);

      expect(result.applied, isTrue);
      expect(result.rowsWritten, 3);
      expect(result.skipReason, isNull);
    });
  });

  group('JournalUpdateResult.skipped', () {
    test('sets applied to false and rowsWritten to zero', () {
      final result = JournalUpdateResult.skipped(
        reason: JournalUpdateSkipReason.conflict,
      );

      expect(result.applied, isFalse);
      expect(result.skipReason, JournalUpdateSkipReason.conflict);
      expect(result.rowsWritten, 0);
      expect(result.skipped, isTrue);
    });
  });

  group('JournalUpdateSkipReason.label', () {
    test('returns known labels for each reason', () {
      expect(
        JournalUpdateSkipReason.olderOrEqual.label,
        'older_or_equal',
      );
      expect(
        JournalUpdateSkipReason.conflict.label,
        'conflict',
      );
      expect(
        JournalUpdateSkipReason.overwritePrevented.label,
        'overwrite_prevented',
      );
      expect(
        JournalUpdateSkipReason.missingBase.label,
        'missing_base',
      );
    });
  });

  test('skipped getter is inverse of applied', () {
    final applied = JournalUpdateResult.applied();
    final skipped = JournalUpdateResult.skipped(
      reason: JournalUpdateSkipReason.overwritePrevented,
    );

    expect(applied.skipped, isFalse);
    expect(skipped.skipped, isTrue);
  });
}
