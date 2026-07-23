import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow_models.dart';

// The rest of day_agent_workflow_models.dart (tool exceptions, observation
// trimming, scheduled-wake carry-over, counter GC) is exercised through
// day_agent_workflow_test.dart; this file covers the pure schedule helper
// added for the ADR 0032 digest cadence.
void main() {
  group('nextDigestTime', () {
    test('before the digest hour resolves to today at 06:00', () {
      expect(
        nextDigestTime(DateTime(2026, 7, 23, 4, 30)),
        DateTime(2026, 7, 23, 6),
      );
    });

    test('at or after the digest hour resolves to tomorrow at 06:00', () {
      expect(
        nextDigestTime(DateTime(2026, 7, 23, 6)),
        DateTime(2026, 7, 24, 6),
        reason: 'Exactly 06:00 is not strictly ahead — schedule tomorrow.',
      );
      expect(
        nextDigestTime(DateTime(2026, 7, 23, 21, 15)),
        DateTime(2026, 7, 24, 6),
      );
    });

    test('rolls over month boundaries via day arithmetic', () {
      expect(
        nextDigestTime(DateTime(2026, 7, 31, 9)),
        DateTime(2026, 8, 1, 6),
      );
    });
  });
}
