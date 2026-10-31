import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/logic/goal_user_voice.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_check_in_reflection.dart';

import '../../agents/test_data/entity_factories.dart';

GoalCheckInSummary _summary(String entryId, {String? digest, int day = 1}) =>
    GoalCheckInSummary(
      id: 'summary-$entryId',
      sourceEntryId: entryId,
      recordedAt: DateTime(2026, 8, day, 20),
      whatHappened: 'Wrote about the colony move ($entryId).',
      sourceDigest: digest,
    );

void main() {
  final monday = _summary('monday', digest: 'digest-monday');
  final tuesday = _summary('tuesday', digest: 'digest-tuesday', day: 2);
  final legacy = _summary('legacy', day: 3);
  final summaries = [monday, tuesday, legacy];
  final userVoice = [
    // A digest of older months carries no words of its own to answer.
    {'kind': 'digest', 'period': '2026-07', 'digest': 'July, in brief.'},
    for (final summary in summaries) goalUserVoiceEntry(summary),
  ];

  test('the key is the entry and its source digest, or its id for a summary '
      'written before digests existed', () {
    expect(goalCheckInReflectionKey(monday), 'monday:digest-monday');
    expect(goalCheckInReflectionKey(legacy), 'legacy:summary-legacy');
  });

  test('a report from before the record counts as having reflected nothing: '
      'every verbatim check-in is new to it, and no digest is', () {
    for (final standingReport in [
      null,
      makeTestReport(provenance: const {'periodKey': '2026-08-03'}),
    ]) {
      final reflection = goalCheckInReflection(
        userVoice: userVoice,
        summaries: summaries,
        standingReport: standingReport,
      );

      expect(reflection.shownByEntryId.keys, ['monday', 'tuesday', 'legacy']);
      expect(reflection.unreflectedEntryIds, {'monday', 'tuesday', 'legacy'});
    }
  });

  test('a check-in distilled from a chat turn is shown but never new: the '
      'chat already answered it', () {
    final reflection = goalCheckInReflection(
      userVoice: userVoice,
      summaries: summaries,
      standingReport: null,
      answeredEntryIds: {'tuesday'},
    );

    expect(reflection.shownByEntryId.keys, contains('tuesday'));
    expect(reflection.unreflectedEntryIds, {'monday', 'legacy'});
  });

  test('only what the standing report did not record is new — including a '
      'check-in whose words changed since', () {
    final reflection = goalCheckInReflection(
      userVoice: userVoice,
      summaries: summaries,
      standingReport: makeTestReport(
        provenance: const {
          GoalReportProvenanceKeys.checkInsReflected: [
            'monday:digest-monday',
            // Tuesday was re-transcribed after this report: its old digest.
            'tuesday:digest-tuesday-first-transcript',
            'legacy:summary-legacy',
            42,
          ],
        },
      ),
    );

    expect(reflection.unreflectedEntryIds, {'tuesday'});
    expect(reflection.shownByEntryId, hasLength(3));
  });

  test('two check-ins that say the same thing word for word are two things '
      'to answer', () {
    final again = _summary('wednesday', digest: 'digest-monday', day: 3);
    final reflection = goalCheckInReflection(
      userVoice: [goalUserVoiceEntry(monday), goalUserVoiceEntry(again)],
      summaries: [monday, again],
      standingReport: makeTestReport(
        provenance: {
          GoalReportProvenanceKeys.checkInsReflected: [
            goalCheckInReflectionKey(monday),
          ],
        },
      ),
    );

    expect(reflection.unreflectedEntryIds, {'wednesday'});
  });

  test('marks exactly the unreflected verbatim entries and leaves the rest '
      'as they were', () {
    final reflection = goalCheckInReflection(
      userVoice: userVoice,
      summaries: summaries,
      standingReport: makeTestReport(
        provenance: const {
          GoalReportProvenanceKeys.checkInsReflected: [
            'monday:digest-monday',
            'legacy:summary-legacy',
          ],
        },
      ),
    );

    final marked = reflection.mark(userVoice);

    expect(marked, hasLength(userVoice.length));
    expect(
      [
        for (final entry in marked)
          if (entry['sinceLastReport'] == true) entry['sourceEntryId'],
      ],
      ['tuesday'],
    );
    expect(marked.first, same(userVoice.first));
  });

  group('what a report records', () {
    // Monday was answered before; Tuesday and the legacy entry are new.
    final reflection = goalCheckInReflection(
      userVoice: userVoice,
      summaries: summaries,
      standingReport: makeTestReport(
        provenance: const {
          GoalReportProvenanceKeys.checkInsReflected: ['monday:digest-monday'],
        },
      ),
    );

    test('a new check-in the reflection does not name stays new, so the next '
        'report is held to it', () {
      expect(reflection.recordedFor(['tuesday']), [
        'monday:digest-monday',
        'tuesday:digest-tuesday',
      ]);
      expect(reflection.recordedFor(const []), ['monday:digest-monday']);
    });

    test('naming every new one records everything the wake showed', () {
      expect(reflection.recordedFor(['legacy', 'tuesday', 'monday']), [
        'monday:digest-monday',
        'tuesday:digest-tuesday',
        'legacy:summary-legacy',
      ]);
    });

    test('the card is given the recording times of the named check-ins it '
        'showed, oldest first — never of an id it did not show', () {
      expect(reflection.answeredAt(['legacy', 'ghost', 'monday']), [
        monday.recordedAt,
        legacy.recordedAt,
      ]);
    });
  });

  test(
    'a wake with no verbatim check-ins records nothing and asks nothing',
    () {
      final reflection = goalCheckInReflection(
        userVoice: [userVoice.first],
        summaries: summaries,
        standingReport: null,
      );

      expect(reflection.shownByEntryId, isEmpty);
      expect(reflection.unreflectedEntryIds, isEmpty);
      // An entry whose summary is no longer live is not shown either.
      expect(
        goalCheckInReflection(
          userVoice: [goalUserVoiceEntry(monday)],
          summaries: const [],
          standingReport: null,
        ).shownByEntryId,
        isEmpty,
      );
    },
  );
}
