import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_timeline.dart';
import 'package:lotti/widgets/timeline/timeline_view.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // Fixed, never the wall clock: the widget derives TODAY/YESTERDAY from the
  // clock itself, so a run that crossed local midnight between building the
  // fixture and pumping the widget would fail intermittently.
  final today = DateTime(2026, 8, 18, 9);

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
    String? failedAudioId,
    String? durableFailedAudioId,
    ValueChanged<TriggerSkillParams>? onTrigger,
  }) => withClock(
    Clock.fixed(today.add(const Duration(hours: 3))),
    () => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SingleChildScrollView(
            child: GoalCheckInTimeline(
              agentId: 'goal-1',
              maxBeats: maxBeats,
              onOpenReflection: onOpenReflection,
            ),
          ),
        ),
        overrides: [
          goalTimelineItemsProvider('goal-1').overrideWithValue(items),
          for (final item in items.whereType<GoalAudioCheckIn>())
            goalAudioTranscriptionFailedProvider(item.id).overrideWith(
              (ref) async => item.id == durableFailedAudioId,
            ),
          if (failedAudioId != null)
            inferenceStatusControllerProvider((
              id: failedAudioId,
              aiResponseType: AiResponseType.audioTranscription,
            )).overrideWith(
              () => _TestInferenceStatusController(InferenceStatus.error),
            ),
          if (onTrigger != null)
            triggerSkillProvider.overrideWith((ref, params) async {
              onTrigger(params);
            }),
        ],
      ),
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

  testWidgets('a failed transcription is visible and retryable', (
    tester,
  ) async {
    TriggerSkillParams? triggered;
    await pump(
      tester,
      [GoalAudioCheckIn(audio('a1', today))],
      failedAudioId: 'a1',
      onTrigger: (params) => triggered = params,
    );

    expect(find.text('Transcription failed'), findsOneWidget);
    expect(find.text('Transcribing…'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(triggered?.entityId, 'a1');
    expect(triggered?.skillId, skillTranscribeContextId);
  });

  testWidgets('a persisted transcription failure survives transient state', (
    tester,
  ) async {
    await pump(
      tester,
      [GoalAudioCheckIn(audio('a1', today))],
      durableFailedAudioId: 'a1',
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Transcription failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
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

  testWidgets('the full timeline pages older beats twenty at a time', (
    tester,
  ) async {
    await pump(tester, [
      for (var i = 0; i < 21; i++)
        GoalAudioCheckIn(
          audio(
            'a$i',
            today.subtract(Duration(minutes: i)),
            transcript: 'note $i',
          ),
        ),
    ]);

    expect(find.text('note 19'), findsOneWidget);
    expect(find.text('note 20'), findsNothing);
    final loadOlder = find.text('Load older');
    expect(loadOlder, findsOneWidget);

    await tester.ensureVisible(loadOlder);
    await tester.tap(loadOlder);
    await tester.pump();

    expect(find.text('note 20'), findsOneWidget);
    expect(find.text('Load older'), findsNothing);
  });

  testWidgets('switching goals resets full-timeline paging', (tester) async {
    final firstItems = [
      for (var i = 0; i < 21; i++)
        GoalAudioCheckIn(
          audio(
            'first-$i',
            today.subtract(Duration(minutes: i)),
            transcript: 'first note $i',
          ),
        ),
    ];
    final secondItems = [
      for (var i = 0; i < 21; i++)
        GoalAudioCheckIn(
          audio(
            'second-$i',
            today.subtract(Duration(minutes: i)),
            transcript: 'second note $i',
          ),
        ),
    ];
    var agentId = 'goal-1';
    late StateSetter updateHost;

    await withClock(
      Clock.fixed(today.add(const Duration(hours: 3))),
      () => tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  updateHost = setState;
                  return GoalCheckInTimeline(agentId: agentId);
                },
              ),
            ),
          ),
          overrides: [
            goalTimelineItemsProvider(
              'goal-1',
            ).overrideWithValue(firstItems),
            goalTimelineItemsProvider(
              'goal-2',
            ).overrideWithValue(secondItems),
          ],
        ),
      ),
    );

    await tester.ensureVisible(find.text('Load older'));
    await tester.tap(find.text('Load older'));
    await tester.pump();
    expect(find.text('first note 20'), findsOneWidget);

    updateHost(() => agentId = 'goal-2');
    await tester.pump();

    expect(find.text('first note 20'), findsNothing);
    expect(find.text('second note 19'), findsOneWidget);
    expect(find.text('second note 20'), findsNothing);
    expect(find.text('Load older'), findsOneWidget);
  });

  testWidgets('a written check-in shows its words under a NOTE label', (
    tester,
  ) async {
    await pump(tester, [
      GoalTextCheckIn(
        JournalEntry(
          meta: meta('n1', today),
          entryText: const EntryText(plainText: 'Gym bag is packed.'),
        ),
      ),
    ]);

    expect(find.text('NOTE'), findsOneWidget);
    expect(find.text('Gym bag is packed.'), findsOneWidget);
    // A written check-in is not a recording: no player, no pending marker.
    expect(find.text('Transcribing…'), findsNothing);
  });

  testWidgets('an older day carries its date, not a relative word', (
    tester,
  ) async {
    await pump(tester, [
      GoalAudioCheckIn(
        audio(
          'old',
          today.subtract(const Duration(days: 3)),
          transcript: 'older note',
        ),
      ),
    ]);

    // TODAY/YESTERDAY stop being useful past two days; a rail spanning months
    // has to stay navigable.
    expect(find.text('TODAY'), findsNothing);
    expect(find.text('YESTERDAY'), findsNothing);
    expect(find.textContaining('AUG'), findsOneWidget);
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

class _TestInferenceStatusController extends InferenceStatusController {
  _TestInferenceStatusController(this.initial);

  final InferenceStatus initial;

  @override
  InferenceStatus build() => initial;
}
