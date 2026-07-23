import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow_models.dart';

import '../../../agents/test_data/entity_factories.dart';

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

  group('selectDigestStatusEvents', () {
    DayStatusEventEntity event(
      String id,
      DateTime raisedAt, {
      DayStatusKind status = DayStatusKind.attentionNeeded,
      List<DayStatusReason> reasons = const [DayStatusReason.overCommitted],
    }) => makeTestDayStatusEvent(
      id: id,
      status: status,
      reasons: reasons,
      raisedAt: raisedAt,
      createdAt: raisedAt,
    );

    test('within the limit everything survives, chronologically', () {
      final (:selected, :truncated) = selectDigestStatusEvents(
        [
          event('b', DateTime(2026, 7, 23, 12)),
          event('a', DateTime(2026, 7, 23, 8)),
        ],
        limit: 2,
      );

      expect(truncated, isFalse);
      expect([for (final e in selected) e.id], ['a', 'b']);
    });

    test('severity outranks age when truncating: an old escalation beats a '
        'new routine close', () {
      final (:selected, :truncated) = selectDigestStatusEvents(
        [
          event(
            'old-escalation',
            DateTime(2026, 7, 22, 8),
            reasons: const [DayStatusReason.directiveUnsatisfiable],
          ),
          event(
            'mid-close',
            DateTime(2026, 7, 22, 21),
            status: DayStatusKind.dayClosed,
            reasons: const [],
          ),
          event(
            'new-ontrack',
            DateTime(2026, 7, 23, 9),
            status: DayStatusKind.onTrack,
            reasons: const [],
          ),
        ],
        limit: 2,
      );

      expect(truncated, isTrue);
      expect(
        [for (final e in selected) e.id],
        ['old-escalation', 'mid-close'],
        reason:
            'The onTrack event is the least decision-relevant despite being '
            'newest; survivors render chronologically.',
      );
    });

    test('reason weight breaks ties within attentionNeeded', () {
      final (:selected, truncated: _) = selectDigestStatusEvents(
        [
          event(
            'newer-divergence',
            DateTime(2026, 7, 23, 10),
            reasons: const [DayStatusReason.userDivergence],
          ),
          event(
            'older-unsatisfiable',
            DateTime(2026, 7, 23, 8),
            reasons: const [DayStatusReason.directiveUnsatisfiable],
          ),
          event(
            'older-blocked',
            DateTime(2026, 7, 23, 6),
            reasons: const [DayStatusReason.processingBlocked],
          ),
        ],
        limit: 2,
      );

      expect(
        [for (final e in selected) e.id],
        ['older-blocked', 'older-unsatisfiable'],
        reason:
            'directiveUnsatisfiable (4) and processingBlocked (2) outrank '
            'userDivergence (1) regardless of recency.',
      );
    });

    test('recency then id give a deterministic total order in a tier', () {
      final t = DateTime(2026, 7, 23, 9);
      final (:selected, truncated: _) = selectDigestStatusEvents(
        [
          event('c-same-time', t),
          event('a-same-time', t),
          event('older', t.subtract(const Duration(hours: 1))),
        ],
        limit: 2,
      );

      expect(
        [for (final e in selected) e.id],
        ['a-same-time', 'c-same-time'],
        reason: 'Equal severity: the two newest survive, id breaks the tie.',
      );
    });
  });
}
