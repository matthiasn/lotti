import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_timeline.dart';
import 'package:lotti/widgets/timeline/timeline_view.dart';

import '../../../../widget_test_utils.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);

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
          dateTo: at.add(const Duration(seconds: 38)),
          audioFile: '$id.m4a',
          audioDirectory: '/audio/',
          duration: const Duration(seconds: 38),
        ),
        entryText: transcript == null ? null : EntryText(plainText: transcript),
      );

  Future<void> pump(
    WidgetTester tester,
    List<GoalTimelineItem> items, {
    ValueChanged<DateTime>? onOpenReflection,
    int? maxBeats,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      GoalCheckInTimeline(
        agentId: 'goal-1',
        maxBeats: maxBeats,
        onOpenReflection: onOpenReflection,
      ),
      overrides: [
        goalTimelineItemsProvider('goal-1').overrideWithValue(items),
      ],
    ),
  );

  testWidgets('an empty rail invites rather than apologises', (tester) async {
    await pump(tester, const []);

    expect(
      find.textContaining('Tell your agent what is actually going on'),
      findsOneWidget,
    );
    expect(find.byType(TimelineView), findsOneWidget);
  });

  testWidgets('a recording without a transcript still plays, and says why', (
    tester,
  ) async {
    await pump(tester, [GoalAudioCheckIn(audio('a1', today))]);

    // The recording is saved before it is transcribed; withholding the beat
    // would hide what the user just made.
    expect(find.text('VOICE CHECK-IN'), findsOneWidget);
    expect(find.text('Transcribing…'), findsOneWidget);
  });

  testWidgets('a transcribed recording shows its words, not a pending marker', (
    tester,
  ) async {
    await pump(tester, [
      GoalAudioCheckIn(audio('a1', today, transcript: 'Skipped the walk.')),
    ]);

    expect(find.text('Skipped the walk.'), findsOneWidget);
    expect(find.text('Transcribing…'), findsNothing);
  });

  testWidgets('a reflection beat carries its verdict and reopens that day', (
    tester,
  ) async {
    final day = DateTime.utc(2026, 8, 17);
    DateTime? reopened;
    await pump(
      tester,
      [
        GoalReflectionItem(
          GoalAssessmentRecord(
            id: 'r1',
            day: day,
            specVersionId: 'spec-1',
            rating: GoalAssessmentRating.mixed,
            createdAt: today,
            note: 'Cutoff held, but the evening was scattered.',
            dimensionRatings: const {
              'a': GoalAssessmentRating.met,
              'b': GoalAssessmentRating.missed,
            },
            provenance: GoalAssessmentProvenance.ratedByUser,
          ),
        ),
      ],
      onOpenReflection: (d) => reopened = d,
    );

    expect(find.text('DAILY REFLECTION'), findsOneWidget);
    expect(find.text('Mixed'), findsOneWidget);
    expect(find.text('2 dimensions rated'), findsOneWidget);
    expect(
      find.text('Cutoff held, but the evening was scattered.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Mixed'));
    // Tapping a reflection reopens the same sheet the day strip does, rather
    // than a second surface that could disagree with it.
    expect(reopened, day);
  });

  testWidgets('the inline preview caps the rail without hiding the rest', (
    tester,
  ) async {
    await pump(
      tester,
      [
        for (var i = 0; i < 6; i++)
          GoalAudioCheckIn(
            audio(
              'a$i',
              today.subtract(Duration(minutes: i)),
              transcript: 'n$i',
            ),
          ),
      ],
      maxBeats: 3,
    );

    expect(find.text('n0'), findsOneWidget);
    expect(find.text('n2'), findsOneWidget);
    expect(find.text('n3'), findsNothing);
  });

  testWidgets('beats are grouped under a day divider', (tester) async {
    await pump(tester, [
      GoalAudioCheckIn(audio('today', today, transcript: 'today note')),
      GoalAudioCheckIn(
        audio(
          'yesterday',
          today.subtract(const Duration(days: 1)),
          transcript: 'yesterday note',
        ),
      ),
    ]);

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
  });
}
