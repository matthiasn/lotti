import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_assessment.dart';
import 'package:lotti/features/goals/model/goal_timeline_item.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_timeline.dart';
import 'package:lotti/features/speech/ui/widgets/recording_playback.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
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
                () => FixedInferenceStatusController(InferenceStatus.error),
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

  testWidgets('a check-in beat carries the time it counts for', (
    tester,
  ) async {
    final spoken = audio('a1', today, transcript: 'Walked after lunch.');
    final timed = spoken.copyWith(
      meta: spoken.meta.copyWith(
        dateTo: today.add(const Duration(minutes: 3, seconds: 10)),
      ),
    );
    await pump(tester, [GoalAudioCheckIn(timed)]);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('goal-checkin-time-a1')),
        matching: find.text('3 min'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a check-in with no time on it offers to add some', (
    tester,
  ) async {
    final written = JournalEntry(
      meta: meta('n1', today),
      entryText: const EntryText(plainText: 'Packed the gym bag.'),
    );
    await pump(tester, [GoalTextCheckIn(written)]);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('goal-checkin-time-n1')),
        matching: find.text('Add time'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an empty rail invites rather than apologises', (tester) async {
    await pump(tester, const []);

    expect(
      find.textContaining('Tell your agent what is actually going on'),
      findsOneWidget,
    );
    // The design system's empty state, as the person timeline's is.
    expect(find.byType(DesignSystemEmptyState), findsOneWidget);
    expect(find.byType(DesignSystemTimelineRow), findsNothing);
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
    // The person timeline's row: a tile, then time and kind on one caption
    // line — sentence case, never the old upper-case eyebrow.
    final row = find.byKey(const ValueKey('goal-checkin-row-a1'));
    expect(
      tester.widget<DesignSystemTimelineRow>(row).leading,
      isA<DesignSystemTimelineTile>().having(
        (t) => t.icon,
        'icon',
        LottiIcons.mic,
      ),
    );
    expect(
      find.descendant(of: row, matching: find.text('11:59 · Voice check-in')),
      findsOneWidget,
    );
    // Played lightly in place, not under a full player card.
    expect(
      find.descendant(of: row, matching: find.byType(RecordingPlayback)),
      findsOneWidget,
    );
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
      Clock.fixed(recordedAt.add(kTranscriptGrace)),
      () async {
        await tester.pump(kTranscriptGrace);
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
      Clock.fixed(older.add(kTranscriptGrace)),
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
            rating: DayVerdict.mixed,
            createdAt: today,
            note: 'Cutoff held, but the evening was scattered.',
            dimensionRatings: const {
              'a': DayVerdict.met,
              'b': DayVerdict.missed,
            },
            provenance: DayVerdictProvenance.ratedByUser,
          ),
        ),
      ],
      onOpenReflection: (d) => reopened = d,
    );

    expect(find.text('Mixed'), findsOneWidget);
    expect(
      find.text('Cutoff held, but the evening was scattered.'),
      findsOneWidget,
    );
    // The verdict rides the row's trailing slot, level with the meta line
    // and to its right; the per-dimension count is the row's footer.
    final row = tester.widget<DesignSystemTimelineRow>(
      find.byKey(const ValueKey('goal-checkin-row-r1')),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('goal-checkin-row-r1')),
        matching: find.textContaining('Daily reflection'),
      ),
      findsOneWidget,
    );
    expect((row.footer! as Text).data, '2 dimensions rated');
    final kind = tester.getRect(find.textContaining('Daily reflection'));
    final pill = tester.getRect(find.text('Mixed'));
    expect(pill.center.dy, closeTo(kind.center.dy, 4));
    expect(pill.left, greaterThan(kind.right));

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

  testWidgets('a written check-in shows its words under a Note label, in '
      'the fold spoken words use', (
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

    expect(find.textContaining('Note'), findsOneWidget);
    expect(
      tester.widget<FoldedWords>(find.byType(FoldedWords)).words,
      'Gym bag is packed.',
    );
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
          rating: DayVerdict.met,
          createdAt: today,
          // ignore: avoid_redundant_argument_values
          dimensionRatings: const {},
          provenance: DayVerdictProvenance.ratedByUser,
        ),
      ),
    ]);

    // The rail shows folded words and a play glyph; the entry itself is
    // where the words can be read whole. Every check-in row opens its entry;
    // the reflection, which is no journal entry, opens nothing here.
    Finder rowOf(String id) => find.byKey(ValueKey('goal-checkin-row-$id'));
    expect(
      tester.widget<DesignSystemTimelineRow>(rowOf('a1')).onTap,
      isNotNull,
    );
    expect(
      tester.widget<DesignSystemTimelineRow>(rowOf('n1')).onTap,
      isNotNull,
    );
    expect(tester.widget<DesignSystemTimelineRow>(rowOf('r1')).onTap, isNull);

    final routes = <String>[];
    beamToNamedOverride = routes.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.tap(find.text('Gym bag is packed.'));
    await tester.pump();
    await tester.tap(find.text('Ran 5k.'));
    await tester.pump();

    // The logbook route for that entry, not a goal-local surface that would
    // then have to reimplement editing and deletion — a note's and a
    // recording's alike.
    expect(routes, ['/journal/n1', '/journal/a1']);
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

    // Today/Yesterday stop being useful past two days; a rail spanning months
    // has to stay navigable. Sentence case, never upper case.
    expect(find.text('Today'), findsNothing);
    expect(find.text('Yesterday'), findsNothing);
    expect(
      tester
          .widget<DesignSystemTimelineSectionHeader>(
            find.byType(DesignSystemTimelineSectionHeader),
          )
          .label,
      'Saturday · 15 Aug',
    );
  });

  testWidgets('beats are grouped under a section header per day, the '
      "person timeline's", (tester) async {
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

    expect(
      tester
          .widgetList<DesignSystemTimelineSectionHeader>(
            find.byType(DesignSystemTimelineSectionHeader),
          )
          .map((h) => h.label),
      ['Today', 'Yesterday'],
    );
    // The last row of a day ends its rail there.
    expect(
      tester
          .widget<DesignSystemTimelineRow>(
            find.byKey(const ValueKey('goal-checkin-row-today')),
          )
          .last,
      isTrue,
    );
  });
}
