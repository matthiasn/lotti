import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/goals/logic/goal_timeline_projection.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';

void main() {
  final day = DateTime(2026, 8, 18);

  Metadata meta(String id, DateTime at) => Metadata(
    id: id,
    createdAt: at,
    updatedAt: at,
    dateFrom: at,
    dateTo: at,
  );

  JournalAudio audio(String id, DateTime at, {String? transcript}) =>
      JournalAudio(
        meta: meta(id, at),
        data: AudioData(
          dateFrom: at,
          dateTo: at.add(const Duration(seconds: 42)),
          audioFile: '$id.m4a',
          audioDirectory: '/audio/',
          duration: const Duration(seconds: 42),
        ),
        entryText: transcript == null ? null : EntryText(plainText: transcript),
      );

  JournalEntry note(String id, DateTime at, String text) => JournalEntry(
    meta: meta(id, at),
    entryText: EntryText(plainText: text),
  );

  GoalAssessmentRecord reflection(
    String id,
    DateTime recordedDay, {
    required DateTime createdAt,
    String specVersionId = 'spec-1',
    GoalAssessmentRating rating = GoalAssessmentRating.mixed,
  }) => GoalAssessmentRecord(
    id: id,
    day: recordedDay,
    specVersionId: specVersionId,
    rating: rating,
    createdAt: createdAt,
    provenance: GoalAssessmentProvenance.ratedByUser,
  );

  group('goalTimelineItems', () {
    test('merges both stores newest first', () {
      final items = goalTimelineItems(
        entries: [
          audio('a1', day.add(const Duration(hours: 9))),
          note('n1', day.add(const Duration(hours: 13)), 'Gym bag packed.'),
        ],
        assessments: [
          reflection(
            'r1',
            DateTime.utc(2026, 8, 17),
            createdAt: day.add(const Duration(hours: 11)),
          ),
        ],
        specVersionId: 'spec-1',
      );

      expect(items.map((i) => i.id), ['n1', 'r1', 'a1']);
      expect(items[0], isA<GoalTextCheckIn>());
      expect(items[1], isA<GoalReflectionItem>());
      expect(items[2], isA<GoalAudioCheckIn>());
    });

    test('keeps only the standing reflection for a day', () {
      // A day reflected on twice is one beat, not two.
      final items = goalTimelineItems(
        entries: const [],
        assessments: [
          reflection(
            'early',
            DateTime.utc(2026, 8, 17),
            createdAt: day.add(const Duration(hours: 9)),
          ),
          reflection(
            'later',
            DateTime.utc(2026, 8, 17),
            createdAt: day.add(const Duration(hours: 21)),
            rating: GoalAssessmentRating.met,
          ),
        ],
        specVersionId: 'spec-1',
      );

      expect(items, hasLength(1));
      expect((items.single as GoalReflectionItem).record.id, 'later');
    });

    test('excludes reflections judged under a superseded spec', () {
      final items = goalTimelineItems(
        entries: const [],
        assessments: [
          reflection(
            'old-spec',
            DateTime.utc(2026, 8, 16),
            createdAt: day,
            specVersionId: 'spec-0',
          ),
          reflection(
            'current',
            DateTime.utc(2026, 8, 17),
            createdAt: day,
          ),
        ],
        specVersionId: 'spec-1',
      );

      // A verdict passed on criteria that no longer exist is not a judgement
      // of the goal as it stands.
      expect(items.map((i) => i.id), ['current']);
    });

    test('drops entries that are not check-ins, and empty notes', () {
      final items = goalTimelineItems(
        entries: [
          note('blank', day, '   '),
          Task(
            meta: meta('task-1', day),
            data: TaskData(
              title: 'unrelated',
              status: TaskStatus.open(
                id: 's',
                createdAt: day,
                utcOffset: 0,
              ),
              dateFrom: day,
              dateTo: day,
              statusHistory: const <TaskStatus>[],
            ),
          ),
          audio('a1', day),
        ],
        assessments: const [],
      );

      expect(items.map((i) => i.id), ['a1']);
    });

    test('a deleted check-in disappears from the timeline', () {
      // The link is not tombstoned with the entry, so the resolved-entry
      // provider can still hand back deleted content — which would stay
      // visible and playable long after the user removed it.
      final deleted = audio('gone', day);
      final items = goalTimelineItems(
        entries: [
          JournalAudio(
            meta: deleted.meta.copyWith(deletedAt: day),
            data: deleted.data,
          ),
          audio('kept', day),
        ],
        assessments: const [],
      );

      expect(items.map((i) => i.id), ['kept']);
    });

    test('reflections are withheld until the current spec is known', () {
      // `latestAssessmentsByDay` reads a null spec as "no filter", which would
      // flash verdicts from every superseded version while health resolves —
      // and leave them standing permanently on a health error.
      final assessments = [
        reflection(
          'r1',
          DateTime.utc(2026, 8, 17),
          createdAt: day,
          specVersionId: 'spec-0',
        ),
      ];

      expect(
        goalTimelineItems(entries: const [], assessments: assessments),
        isEmpty,
      );
      expect(
        goalTimelineItems(
          entries: const [],
          assessments: assessments,
          specVersionId: 'spec-0',
        ),
        hasLength(1),
      );
    });

    test('check-ins still show while the spec is unknown', () {
      // Only the REFLECTIONS depend on the spec; a check-in is the user's own
      // words and is not a judgement of any criteria.
      final items = goalTimelineItems(
        entries: [audio('a1', day)],
        assessments: const [],
      );
      expect(items, hasLength(1));
    });

    test('a recording with no transcript yet still becomes a beat', () {
      // The recording is saved before it is transcribed; withholding the beat
      // until words exist would hide what the user just made.
      final items = goalTimelineItems(
        entries: [audio('a1', day)],
        assessments: const [],
      );

      expect((items.single as GoalAudioCheckIn).transcript, isNull);
    });

    test('orders same-instant items deterministically', () {
      final at = day.add(const Duration(hours: 9));
      final first = goalTimelineItems(
        entries: [audio('aaa', at), audio('bbb', at)],
        assessments: const [],
      );
      final second = goalTimelineItems(
        entries: [audio('bbb', at), audio('aaa', at)],
        assessments: const [],
      );

      // Same data in a different order must not reshuffle the rail.
      expect(first.map((i) => i.id), second.map((i) => i.id));
    });
  });

  group('groupGoalItemsByDay', () {
    test('opens a group per local calendar day, in order', () {
      final items = goalTimelineItems(
        entries: [
          audio('today-late', day.add(const Duration(hours: 20))),
          audio('today-early', day.add(const Duration(hours: 7))),
          audio('yesterday', day.subtract(const Duration(hours: 3))),
        ],
        assessments: const [],
      );

      final groups = groupGoalItemsByDay(
        items,
        labelForDay: (d) => '${d.year}-${d.month}-${d.day}',
      );

      expect(groups.map((g) => g.label), ['2026-8-18', '2026-8-17']);
      expect(groups.first.items.map((i) => i.id), [
        'today-late',
        'today-early',
      ]);
      expect(groups.last.items.single.id, 'yesterday');
    });

    test('no items means no groups, not an empty day', () {
      expect(groupGoalItemsByDay(const [], labelForDay: (_) => 'x'), isEmpty);
    });
  });
}
