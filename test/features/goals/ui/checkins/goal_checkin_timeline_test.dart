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
import 'package:lotti/services/nav_service.dart';
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
    // The settle pump belongs INSIDE the fixed clock. The transcription-failure
    // lookup resolves a frame late, and that rebuild is the one that asks
    // `clock.now()` how long a recording has been waiting — outside, it would
    // read the wall clock and call every fixture stalled.
    () async {
      await tester.pumpWidget(
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
      );
      await tester.pump();
    },
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
    // Just recorded: the entry exists before its transcript, deliberately.
    await pump(tester, [
      GoalAudioCheckIn(
        audio('a1', today.add(const Duration(hours: 2, minutes: 59))),
      ),
    ]);

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

  testWidgets('a recording still inside the grace window reads as pending', (
    tester,
  ) async {
    // The normal case for the first minutes after recording: the entry exists
    // before the transcript, deliberately, so the rail must not accuse a
    // provider that is simply still working.
    await pump(tester, [
      GoalAudioCheckIn(
        audio('fresh', today.add(const Duration(hours: 2, minutes: 55))),
      ),
    ]);

    expect(find.text('Transcribing…'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('the rail wakes itself when the grace window closes', (
    tester,
  ) async {
    // Recorded five minutes before "now", so it starts inside the window.
    final recordedAt = today.add(const Duration(hours: 2, minutes: 55));
    await pump(tester, [GoalAudioCheckIn(audio('waiting', recordedAt))]);

    expect(find.text('Transcribing…'), findsOneWidget);

    // Nothing else will rebuild this beat: no transcript is coming, no
    // inference status will change, no database notification will fire. If the
    // rail does not wake itself, the one case the stalled state exists to
    // catch is the one case nobody ever sees.
    await withClock(
      Clock.fixed(recordedAt.add(kGoalCheckInTranscriptGrace)),
      () async {
        await tester.pump(kGoalCheckInTranscriptGrace);
        await tester.pump();
      },
    );

    expect(find.text('Not transcribed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Transcribing…'), findsNothing);
  });

  testWidgets('the rail takes its pending timer with it when it goes', (
    tester,
  ) async {
    // Arms a timer for a recording five minutes short of its deadline.
    await pump(tester, [
      GoalAudioCheckIn(
        audio('waiting', today.add(const Duration(hours: 2, minutes: 55))),
      ),
    ]);
    expect(find.text('Transcribing…'), findsOneWidget);

    // Navigating away mid-window is ordinary — the rail is a card on a page
    // the user leaves — and the timer has to go with it.
    await tester.pumpWidget(const SizedBox.shrink());
    // Deliberately NOT past the deadline: a timer that is allowed to fire is
    // caught by the `mounted` guard and leaves nothing pending, so advancing
    // past it would prove the guard rather than the cancel. Stopping short
    // leaves the timer live unless `dispose` cancelled it, and the binding's
    // pending-timer check at teardown is then the assertion.
    await tester.pump(const Duration(minutes: 1));

    expect(find.byType(GoalCheckInTimeline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail wakes for the soonest beat, not the newest', (
    tester,
  ) async {
    // Two recordings waiting, four minutes apart. The rail may only hold one
    // timer, so it has to be the one that expires first — arming for the later
    // one would leave the other beat claiming progress past its own window.
    //
    // Ordering is the caller's throughout this component, so the soonest
    // deadline is found by comparing rather than by trusting the list to be
    // sorted: these are deliberately supplied oldest-first.
    final older = today.add(const Duration(hours: 2, minutes: 51));
    final newer = today.add(const Duration(hours: 2, minutes: 55));
    await pump(tester, [
      GoalAudioCheckIn(audio('older', older)),
      GoalAudioCheckIn(audio('newer', newer)),
    ]);

    expect(find.text('Transcribing…'), findsNWidgets(2));

    await withClock(
      Clock.fixed(older.add(kGoalCheckInTranscriptGrace)),
      () async {
        await tester.pump(const Duration(minutes: 1));
        await tester.pump();
      },
    );

    // The older one has crossed; the newer one has four minutes left.
    expect(find.text('Not transcribed'), findsOneWidget);
    expect(find.text('Transcribing…'), findsOneWidget);
  });

  testWidgets('a recording nothing ever picked up becomes retryable', (
    tester,
  ) async {
    // Past the grace window the same picture means the opposite: nobody picked
    // the recording up. Every check-in recorded before transcription was wired
    // is permanently in this state, and the retry only ever appeared on a
    // *failed* run — so there was no way back to the words.
    TriggerSkillParams? triggered;
    await pump(
      tester,
      [GoalAudioCheckIn(audio('stale', today))],
      onTrigger: (params) => triggered = params,
    );

    expect(find.text('Not transcribed'), findsOneWidget);
    // Not "failed": nothing ran, and claiming an attempt that never happened
    // would send the user looking for a provider error that does not exist.
    expect(find.text('Transcription failed'), findsNothing);
    expect(find.text('Transcribing…'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(triggered?.entityId, 'stale');
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

  testWidgets('check-ins open their journal entry, reflections do not', (
    tester,
  ) async {
    await pump(tester, [
      GoalAudioCheckIn(audio('a1', today, transcript: 'Ran 5k.')),
      GoalTextCheckIn(
        JournalEntry(
          meta: meta('n1', today),
          entryText: const EntryText(plainText: 'Gym bag is packed.'),
        ),
      ),
      GoalReflectionItem(
        GoalAssessmentRecord(
          id: 'r1',
          day: DateTime.utc(today.year, today.month, today.day),
          specVersionId: 'spec-1',
          rating: GoalAssessmentRating.met,
          createdAt: today,
          // ignore: avoid_redundant_argument_values
          dimensionRatings: const {},
          provenance: GoalAssessmentProvenance.ratedByUser,
        ),
      ),
    ]);

    // The rail shows a clamped transcript and a player; the entry itself is
    // where the words can be read whole. The chevron is the shared timeline's
    // contract for "this row opens something" — it is drawn only when both an
    // entry id and an open handler are present, so two of the three beats
    // carry it and the agent-side reflection, which is no journal entry,
    // does not.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));

    final routes = <String>[];
    beamToNamedOverride = routes.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.tap(find.text('Gym bag is packed.'));
    await tester.pump();

    // The logbook route for that entry, not a goal-local surface that would
    // then have to reimplement editing and deletion.
    expect(routes, ['/journal/n1']);
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
