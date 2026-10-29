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

  test('the key is the source digest, or the id for a summary written before '
      'digests existed', () {
    expect(goalCheckInReflectionKey(monday), 'digest-monday');
    expect(goalCheckInReflectionKey(legacy), 'summary-legacy');
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

      expect(reflection.shown, [
        'digest-monday',
        'digest-tuesday',
        'summary-legacy',
      ]);
      expect(reflection.unreflectedEntryIds, {'monday', 'tuesday', 'legacy'});
    }
  });

  test('only what the standing report did not record is new — including a '
      'check-in whose words changed since', () {
    final reflection = goalCheckInReflection(
      userVoice: userVoice,
      summaries: summaries,
      standingReport: makeTestReport(
        provenance: const {
          GoalReportProvenanceKeys.checkInsReflected: [
            'digest-monday',
            // Tuesday was re-transcribed after this report: its old digest.
            'digest-tuesday-first-transcript',
            'summary-legacy',
            42,
          ],
        },
      ),
    );

    expect(reflection.unreflectedEntryIds, {'tuesday'});
    expect(reflection.shown, hasLength(3));
  });

  test('marks exactly the unreflected verbatim entries and leaves the rest '
      'as they were', () {
    final reflection = goalCheckInReflection(
      userVoice: userVoice,
      summaries: summaries,
      standingReport: makeTestReport(
        provenance: const {
          GoalReportProvenanceKeys.checkInsReflected: [
            'digest-monday',
            'summary-legacy',
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

  test(
    'a wake with no verbatim check-ins records nothing and asks nothing',
    () {
      final reflection = goalCheckInReflection(
        userVoice: [userVoice.first],
        summaries: summaries,
        standingReport: null,
      );

      expect(reflection.shown, isEmpty);
      expect(reflection.unreflectedEntryIds, isEmpty);
      // An entry whose summary is no longer live is not shown either.
      expect(
        goalCheckInReflection(
          userVoice: [goalUserVoiceEntry(monday)],
          summaries: const [],
          standingReport: null,
        ).shown,
        isEmpty,
      );
    },
  );
}
