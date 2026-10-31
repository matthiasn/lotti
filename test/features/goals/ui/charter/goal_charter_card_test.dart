import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/goals/logic/goal_charter.dart';
import 'package:lotti/features/goals/state/goal_charter_providers.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_card.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_sheet.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/ui/evolution/widgets/evolution_recorder_test_utils.dart';

void main() {
  JournalEntry entry(String id, String text, {int day = 1}) =>
      testTextEntryNoGeo.copyWith(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: id,
          dateFrom: DateTime(2026, 8, day),
        ),
        entryText: EntryText(plainText: text),
      );

  final now = DateTime(2026, 8, 11, 12);

  JournalAudio recording(String id, {String? transcript, DateTime? at}) =>
      JournalAudio(
        meta: testTextEntryNoGeo.meta.copyWith(
          id: id,
          dateFrom: at ?? now.subtract(const Duration(minutes: 1)),
        ),
        data: AudioData(
          dateFrom: now,
          dateTo: now,
          audioFile: '$id.m4a',
          audioDirectory: '/audio/',
          duration: const Duration(seconds: 30),
        ),
        entryText: transcript == null ? null : EntryText(plainText: transcript),
      );

  Future<void> pump(
    WidgetTester tester, {
    required Future<List<JournalEntity>> Function() entries,
    bool editable = true,
    List<Override> overrides = const [],
  }) => withClock(Clock.fixed(now), () async {
    await tester.pumpWidget(
      makeTestableWidget(
        GoalCharterCard(agentId: 'agent-1', editable: editable),
        overrides: [
          goalCharterEntriesProvider(
            'agent-1',
          ).overrideWith((ref) => entries()),
          chatRecorderControllerProvider.overrideWith(
            TranscriptEmittingController.new,
          ),
          ...overrides,
        ],
      ),
    );
    await tester.pump();
    // The durable-failure lookup resolves a frame late; that rebuild reads
    // the clock, so it belongs inside the fixed one.
    await tester.pump();
  });

  testWidgets('lists the charter in full, in the order it was written', (
    tester,
  ) async {
    await pump(
      tester,
      entries: () async => [
        entry('purpose', 'This goal is my journal.'),
        entry('style', 'Ask me one guided question each morning.', day: 2),
      ],
    );

    expect(find.text('About this goal'), findsOneWidget);
    final purpose = tester.getTopLeft(find.text('This goal is my journal.'));
    final style = tester.getTopLeft(
      find.text('Ask me one guided question each morning.'),
    );
    expect(purpose.dy, lessThan(style.dy));
    expect(find.byKey(const ValueKey('goal-charter-add')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-charter-over-budget')),
      findsNothing,
    );
  });

  testWidgets('tapping an entry opens its sheet on its words', (tester) async {
    await pump(
      tester,
      entries: () async => [entry('purpose', 'This goal is my journal.')],
    );

    await tester.tap(find.byKey(const ValueKey('goal-charter-entry-purpose')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final form = tester.widget<GoalCharterForm>(find.byType(GoalCharterForm));
    expect(form.entry?.meta.id, 'purpose');
    expect(form.agentId, 'agent-1');
  });

  testWidgets('the header adds a new entry', (tester) async {
    await pump(
      tester,
      entries: () async => [entry('purpose', 'This goal is my journal.')],
    );

    await tester.tap(find.byKey(const ValueKey('goal-charter-add')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<GoalCharterForm>(find.byType(GoalCharterForm)).entry,
      isNull,
    );
  });

  testWidgets('with no charter yet, the card invites one', (tester) async {
    await pump(tester, entries: () async => const []);

    expect(
      find.text(
        'Tell your agent what this goal is for and how you want to be '
        'coached. It reads this every time it writes to you.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('goal-charter-add')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('goal-charter-empty-cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GoalCharterForm), findsOneWidget);
  });

  testWidgets('a dormant goal shows its charter but changes nothing', (
    tester,
  ) async {
    await pump(
      tester,
      editable: false,
      entries: () async => [entry('purpose', 'This goal is my journal.')],
    );

    expect(find.text('This goal is my journal.'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-charter-add')), findsNothing);
    expect(
      find.byKey(const ValueKey('goal-charter-entry-purpose')),
      findsNothing,
    );
  });

  testWidgets('a dormant goal without a charter takes no room', (
    tester,
  ) async {
    await pump(tester, editable: false, entries: () async => const []);

    expect(find.byKey(const ValueKey('goal-charter-card')), findsNothing);
  });

  testWidgets('nothing renders until the charter has loaded', (tester) async {
    final pending = Completer<List<JournalEntry>>();
    await pump(tester, entries: () => pending.future);

    expect(find.byKey(const ValueKey('goal-charter-card')), findsNothing);
    pending.complete(const []);
  });

  testWidgets('a charter longer than one wake carries says so', (
    tester,
  ) async {
    final long = List.filled(goalCharterTokenBudget, 'krill').join(' ');
    await pump(
      tester,
      entries: () async => [
        entry('purpose', 'This goal is my journal.'),
        entry('long', long, day: 2),
      ],
    );

    expect(
      find.byKey(const ValueKey('goal-charter-over-budget')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Your agent can only read the first part of this. Shorten or combine '
        'entries so it reads all of it.',
      ),
      findsOneWidget,
    );
  });

  group('a recorded entry', () {
    List<Override> noFailure(String id) => [
      goalAudioTranscriptionFailedProvider(
        id,
      ).overrideWith((ref) async => false),
    ];

    testWidgets('plays, and its transcript opens the sheet to correct', (
      tester,
    ) async {
      await pump(
        tester,
        entries: () async => [
          recording('spoken', transcript: 'Coach me gently.'),
        ],
        overrides: noFailure('spoken'),
      );

      expect(find.byType(AudioPlayerWidget), findsOneWidget);
      expect(find.text('Coach me gently.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('goal-charter-entry-spoken')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final form = tester.widget<GoalCharterForm>(find.byType(GoalCharterForm));
      expect(form.entry, isA<JournalAudio>());
      // The words come from the recording: no dictating into a transcript.
      expect(find.byKey(const ValueKey('goal-charter-dictate')), findsNothing);
    });

    testWidgets('says it is being transcribed while it is', (tester) async {
      await pump(
        tester,
        entries: () async => [recording('spoken')],
        overrides: [
          ...noFailure('spoken'),
          inferenceStatusControllerProvider((
            id: 'spoken',
            aiResponseType: AiResponseType.audioTranscription,
          )).overrideWith(
            () => FixedInferenceStatusController(InferenceStatus.running),
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('transcript-status-spoken')),
        findsOneWidget,
      );
      expect(find.text('Transcribing…'), findsOneWidget);
    });

    for (final (kind, label, at, failed) in [
      (
        'failed',
        'failed',
        null,
        true,
      ),
      (
        'stalled',
        'missing',
        DateTime(2026, 8, 11, 11),
        false,
      ),
    ]) {
      testWidgets('a $kind transcription offers Retry, which transcribes that '
          'recording', (tester) async {
        final triggered = <TriggerSkillParams>[];
        await pump(
          tester,
          entries: () async => [recording('spoken', at: at)],
          overrides: [
            goalAudioTranscriptionFailedProvider(
              'spoken',
            ).overrideWith((ref) async => failed),
            triggerSkillProvider.overrideWith((ref, params) async {
              triggered.add(params);
            }),
          ],
        );

        final context = tester.element(find.byType(GoalCharterCard));
        expect(
          find.text(
            label == 'failed'
                ? context.messages.timelineTranscriptionFailed
                : context.messages.timelineTranscriptMissing,
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('transcript-retry-spoken')),
        );
        await tester.pump();

        expect(triggered.single.entityId, 'spoken');
        expect(triggered.single.skillId, skillTranscribeContextId);
      });
    }

    testWidgets('a recording nobody picks up turns stalled on its own when its '
        'grace window closes', (tester) async {
      // Recorded a minute before "now": inside the window, nothing running.
      await pump(
        tester,
        entries: () async => [recording('spoken')],
        overrides: noFailure('spoken'),
      );
      expect(
        find.byKey(const ValueKey('transcript-status-spoken')),
        findsOneWidget,
      );
      expect(find.text('Transcribing…'), findsOneWidget);

      // Nothing else will rebuild the tile — no transcript, no status change,
      // no notification. Without its own timer it says "Transcribing…" for as
      // long as the page stays open.
      await withClock(
        Clock.fixed(now.add(kTranscriptGrace)),
        () async {
          await tester.pump(kTranscriptGrace);
          await tester.pump();
        },
      );

      expect(
        find.byKey(const ValueKey('transcript-status-spoken')),
        findsOneWidget,
      );
      expect(find.text('Not transcribed'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('transcript-retry-spoken')),
        findsOneWidget,
      );
    });

    testWidgets('a recording waiting for words keeps the over-budget notice '
        'away', (tester) async {
      await pump(
        tester,
        entries: () async => [recording('spoken')],
        overrides: noFailure('spoken'),
      );

      expect(
        find.byKey(const ValueKey('goal-charter-over-budget')),
        findsNothing,
      );
    });
  });

  testWidgets('an active goal records from the header', (tester) async {
    await pump(
      tester,
      entries: () async => [entry('purpose', 'This goal is my journal.')],
    );

    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('goal-charter-record')))
          .tooltip,
      'Record about this goal',
    );
  });

  testWidgets('an empty charter invites a recording as well as writing', (
    tester,
  ) async {
    await pump(tester, entries: () async => const []);

    expect(
      find.byKey(const ValueKey('goal-charter-empty-record')),
      findsOneWidget,
    );
    expect(find.text('Record about this goal'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-charter-empty-cta')), findsOne);
  });

  testWidgets('a dormant goal records nothing either', (tester) async {
    await pump(
      tester,
      editable: false,
      entries: () async => [entry('purpose', 'This goal is my journal.')],
    );

    expect(find.byKey(const ValueKey('goal-charter-record')), findsNothing);
  });
}
