import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/g_counter.dart';

void main() {
  group('AgentMessageMetadata.milestone', () {
    // The JSON value for each milestone is the cross-device sync wire format
    // and the key the State-as-Projection fold matches on (PR 4). Renaming an
    // enum value would silently break already-synced markers, so pin the exact
    // wire strings here as a regression guard.
    const wireValues = {
      AgentMilestone.wakeCompleted: 'wakeCompleted',
      AgentMilestone.oneOnOneCompleted: 'oneOnOneCompleted',
      AgentMilestone.feedbackScanCompleted: 'feedbackScanCompleted',
      AgentMilestone.dailyWakeCompleted: 'dailyWakeCompleted',
      AgentMilestone.weeklyReviewCompleted: 'weeklyReviewCompleted',
    };

    test('covers every milestone value', () {
      expect(wireValues.keys, unorderedEquals(AgentMilestone.values));
    });

    for (final entry in wireValues.entries) {
      final milestone = entry.key;
      final wire = entry.value;

      test('$milestone serialises to "$wire" and round-trips', () {
        final metadata = AgentMessageMetadata(milestone: milestone);

        // Encode through a real JSON pass to exercise the wire format.
        final json =
            jsonDecode(jsonEncode(metadata.toJson())) as Map<String, dynamic>;
        expect(json['milestone'], wire);

        final restored = AgentMessageMetadata.fromJson(json);
        expect(restored.milestone, milestone);
        expect(restored, metadata);
      });
    }

    test('defaults to null and leaves other fields intact', () {
      const metadata = AgentMessageMetadata(runKey: 'rk-1', toolName: 'tool');

      expect(metadata.milestone, isNull);

      final restored = AgentMessageMetadata.fromJson(metadata.toJson());
      expect(restored.milestone, isNull);
      expect(restored.runKey, 'rk-1');
      expect(restored.toolName, 'tool');
    });

    test('absent milestone key deserialises to null (backward compat)', () {
      // A row written before the field existed has no `milestone` key.
      final restored = AgentMessageMetadata.fromJson(
        const {'runKey': 'rk-legacy'},
      );

      expect(restored.milestone, isNull);
      expect(restored.runKey, 'rk-legacy');
    });

    test(
      'unknown milestone value deserialises to null (forward compat)',
      () {
        // A newer client may emit a milestone this build does not know about;
        // it must degrade to null rather than throw on deserialisation.
        final restored = AgentMessageMetadata.fromJson(
          const {'milestone': 'someFutureMilestone'},
        );

        expect(restored.milestone, isNull);
      },
    );
  });

  group('AgentSlots', () {
    final base = AgentSlots(
      activeTaskId: 'task-1',
      activeDayId: 'day-1',
      activeProjectId: 'project-1',
      activeTemplateId: 'tpl-1',
      lastOneOnOneAt: DateTime(2026, 3),
      lastFeedbackScanAt: DateTime(2026, 3, 2),
      feedbackWindowDays: 7,
      totalSessionsCompleted: const GCounter({'h1': 2}),
      recursionDepth: 1,
      lastDailyWakeAt: DateTime(2026, 3, 3),
      lastWeeklyReviewAt: DateTime(2026, 3, 4),
      weeklyReviewCount: const GCounter({'h1': 1}),
      pendingProjectActivityAt: DateTime(2026, 3, 5),
    );

    test('structurally identical slots are equal with matching hashCodes', () {
      final copy = base.copyWith();
      expect(copy, equals(base));
      expect(copy.hashCode, base.hashCode);
    });

    test('every field participates in equality (single-field mutations)', () {
      final mutations = <String, AgentSlots>{
        'activeTaskId': base.copyWith(activeTaskId: 'task-2'),
        'activeDayId': base.copyWith(activeDayId: 'day-2'),
        'activeProjectId': base.copyWith(activeProjectId: 'project-2'),
        'activeTemplateId': base.copyWith(activeTemplateId: 'tpl-2'),
        'lastOneOnOneAt': base.copyWith(lastOneOnOneAt: DateTime(2026, 4)),
        'lastFeedbackScanAt': base.copyWith(
          lastFeedbackScanAt: DateTime(2026, 4, 2),
        ),
        'feedbackWindowDays': base.copyWith(feedbackWindowDays: 14),
        'totalSessionsCompleted': base.copyWith(
          totalSessionsCompleted: const GCounter({'h1': 3}),
        ),
        'recursionDepth': base.copyWith(recursionDepth: 0),
        'lastDailyWakeAt': base.copyWith(lastDailyWakeAt: DateTime(2026, 4, 3)),
        'lastWeeklyReviewAt': base.copyWith(
          lastWeeklyReviewAt: DateTime(2026, 4, 4),
        ),
        'weeklyReviewCount': base.copyWith(
          weeklyReviewCount: const GCounter({'h1': 2}),
        ),
        'pendingProjectActivityAt': base.copyWith(
          pendingProjectActivityAt: DateTime(2026, 4, 5),
        ),
      };
      for (final MapEntry(key: field, value: mutated) in mutations.entries) {
        expect(mutated, isNot(equals(base)), reason: 'field=$field');
        // copyWith touched only the named field: reverting equality via a
        // fresh copy keeps the rest intact.
        expect(
          mutated.activeTaskId,
          field == 'activeTaskId' ? 'task-2' : base.activeTaskId,
          reason: 'field=$field',
        );
      }
    });

    test('copyWith with explicit null clears nullable slots', () {
      final cleared = base.copyWith(
        activeTaskId: null,
        pendingProjectActivityAt: null,
      );
      expect(cleared.activeTaskId, isNull);
      expect(cleared.pendingProjectActivityAt, isNull);
      // Untouched fields persist.
      expect(cleared.activeProjectId, base.activeProjectId);
      expect(cleared.weeklyReviewCount, base.weeklyReviewCount);
    });

    test('defaults: counters start as empty G-counters', () {
      const fresh = AgentSlots();
      expect(fresh.totalSessionsCompleted, const GCounter.empty());
      expect(fresh.weeklyReviewCount, const GCounter.empty());
      expect(fresh.activeTaskId, isNull);
    });
  });
}
