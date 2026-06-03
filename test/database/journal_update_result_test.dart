import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/journal_update_result.dart';

extension _AnySkipReason on glados.Any {
  glados.Generator<JournalUpdateSkipReason> get skipReason =>
      glados.AnyUtils(this).choose(JournalUpdateSkipReason.values);
}

void main() {
  group('JournalUpdateResult.applied', () {
    test('defaults rowsWritten to 1 when omitted', () {
      final result = JournalUpdateResult.applied();

      expect(result.applied, isTrue);
      expect(result.rowsWritten, 1);
      expect(result.skipReason, isNull);
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

  // -------------------------------------------------------------------------
  // Glados property — LOW item: label is non-empty for every enum value
  // -------------------------------------------------------------------------

  glados.Glados(
    glados.any.skipReason,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'label is non-empty for every JournalUpdateSkipReason value',
    (reason) {
      expect(
        reason.label,
        isNotEmpty,
        reason: 'label must be a non-empty string for $reason',
      );
    },
    tags: 'glados',
  );
}
