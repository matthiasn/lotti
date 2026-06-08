import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/sync/g_counter.dart';

/// Anchors generated `DateTime?` slot fields to a fixed base so the round-trip
/// is deterministic; the per-field day offset varies which calendar day each
/// set field lands on without ever using `DateTime.now()`.
final _slotsBase = DateTime(2026);

/// One generated [AgentSlots] shape exercising the freezed `toJson`/`fromJson`
/// codec (including the `@JsonKey`-renamed counter keys and ISO-8601 `DateTime`
/// encoding). Each nullable field uses a negative day-offset / count sentinel
/// to encode "absent", so the optional-present cross-product and the underlying
/// values both vary, and each input dimension shrinks independently.
class _GeneratedSlotsScenario {
  const _GeneratedSlotsScenario({
    required this.oneOnOneOffset,
    required this.feedbackScanOffset,
    required this.dailyWakeOffset,
    required this.weeklyReviewOffset,
    required this.pendingActivityOffset,
    required this.feedbackWindowDays,
    required this.recursionDepth,
    required this.sessionsByHost,
    required this.weeklyByHost,
  });

  // A negative offset means the corresponding nullable DateTime is absent.
  final int oneOnOneOffset;
  final int feedbackScanOffset;
  final int dailyWakeOffset;
  final int weeklyReviewOffset;
  final int pendingActivityOffset;
  // A negative value means the corresponding nullable int is absent.
  final int feedbackWindowDays;
  final int recursionDepth;
  // Zero means the counter stays empty; positive means a single-host total.
  final int sessionsByHost;
  final int weeklyByHost;

  DateTime? _at(int offset) =>
      offset < 0 ? null : _slotsBase.add(Duration(days: offset));

  AgentSlots get slots => AgentSlots(
    lastOneOnOneAt: _at(oneOnOneOffset),
    lastFeedbackScanAt: _at(feedbackScanOffset),
    feedbackWindowDays: feedbackWindowDays < 0 ? null : feedbackWindowDays,
    totalSessionsCompleted: sessionsByHost > 0
        ? GCounter({'host-a': sessionsByHost})
        : const GCounter.empty(),
    recursionDepth: recursionDepth < 0 ? null : recursionDepth,
    lastDailyWakeAt: _at(dailyWakeOffset),
    lastWeeklyReviewAt: _at(weeklyReviewOffset),
    weeklyReviewCount: weeklyByHost > 0
        ? GCounter({'host-b': weeklyByHost})
        : const GCounter.empty(),
    pendingProjectActivityAt: _at(pendingActivityOffset),
  );

  @override
  String toString() {
    return '_GeneratedSlotsScenario('
        'oneOnOneOffset: $oneOnOneOffset, '
        'feedbackScanOffset: $feedbackScanOffset, '
        'dailyWakeOffset: $dailyWakeOffset, '
        'weeklyReviewOffset: $weeklyReviewOffset, '
        'pendingActivityOffset: $pendingActivityOffset, '
        'feedbackWindowDays: $feedbackWindowDays, '
        'recursionDepth: $recursionDepth, sessionsByHost: $sessionsByHost, '
        'weeklyByHost: $weeklyByHost)';
  }
}

extension _AnyGeneratedSlots on glados.Any {
  glados.Generator<_GeneratedSlotsScenario> get slotsScenario =>
      glados.CombinableAny(this).combine9(
        // Day-offset ranges start at -1 so ~ one run in ~30 omits the field,
        // giving the shrinker a clean "absent" boundary per DateTime slot.
        glados.IntAnys(this).intInRange(-1, 30),
        glados.IntAnys(this).intInRange(-1, 30),
        glados.IntAnys(this).intInRange(-1, 30),
        glados.IntAnys(this).intInRange(-1, 30),
        glados.IntAnys(this).intInRange(-1, 30),
        glados.IntAnys(this).intInRange(-1, 60),
        glados.IntAnys(this).intInRange(-1, 1),
        glados.IntAnys(this).intInRange(0, 1000),
        glados.IntAnys(this).intInRange(0, 1000),
        (
          int oneOnOneOffset,
          int feedbackScanOffset,
          int dailyWakeOffset,
          int weeklyReviewOffset,
          int pendingActivityOffset,
          int feedbackWindowDays,
          int recursionDepth,
          int sessionsByHost,
          int weeklyByHost,
        ) => _GeneratedSlotsScenario(
          oneOnOneOffset: oneOnOneOffset,
          feedbackScanOffset: feedbackScanOffset,
          dailyWakeOffset: dailyWakeOffset,
          weeklyReviewOffset: weeklyReviewOffset,
          pendingActivityOffset: pendingActivityOffset,
          feedbackWindowDays: feedbackWindowDays,
          recursionDepth: recursionDepth,
          sessionsByHost: sessionsByHost,
          weeklyByHost: weeklyByHost,
        ),
      );
}

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

    glados.Glados(
      glados.any.slotsScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'survives a JSON round-trip across optional-field combinations',
      (
        scenario,
      ) {
        final original = scenario.slots;

        // Encode through a real JSON pass so DateTime/ISO-8601 and the
        // @JsonKey-renamed counter keys are exercised exactly as on the wire.
        final json =
            jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
        final restored = AgentSlots.fromJson(json);

        expect(restored, equals(original), reason: '$scenario');

        // Spot-check that the renamed counter keys are the ones actually written,
        // so a future rename of either key is caught even though the round-trip
        // would still pass symmetrically.
        if (original.totalSessionsCompleted.value > 0) {
          expect(json.containsKey('totalSessionsCompletedByHost'), isTrue);
        }
        if (original.weeklyReviewCount.value > 0) {
          expect(json.containsKey('weeklyReviewCountByHost'), isTrue);
        }
      },
      tags: 'glados',
    );
  });
}
