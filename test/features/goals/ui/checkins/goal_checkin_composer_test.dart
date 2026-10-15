import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 8, 18, 14, 20);

  late List<
    ({String text, String goalEntryId, DateTime started, Duration timeSpent})
  >
  saved;
  late List<String> recorded;
  var saveSucceeds = true;
  String? recorderResult;

  setUp(() {
    saved = [];
    recorded = [];
    saveSucceeds = true;
    recorderResult = 'audio-1';
  });

  Future<void> pump(
    WidgetTester tester, {
    String? captureTarget = 'goal-1',
    String? preparedLine,
    String? personaName,
    Clock? clockOverride,
    Duration? pickedDuration,
  }) => withClock(
    clockOverride ?? Clock.fixed(now),
    () => tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        GoalCheckInComposer(
          agentId: 'agent-1',
          goalTitle: 'Fitness',
          preparedLine: preparedLine,
          personaName: personaName,
          categoryId: 'cat-1',
          saveText:
              ({
                required text,
                required goalEntryId,
                required started,
                required timeSpent,
                categoryId,
              }) async {
                saved.add((
                  text: text,
                  goalEntryId: goalEntryId,
                  started: started,
                  timeSpent: timeSpent,
                ));
                return saveSucceeds;
              },
          pickDuration: ({required context, required initialDuration}) async =>
              pickedDuration,
          openRecorder: (context, {required goalEntryId, categoryId}) async {
            recorded.add(goalEntryId);
            return recorderResult;
          },
        ),
        overrides: [
          goalCaptureTargetProvider(
            'agent-1',
          ).overrideWith((ref) async => captureTarget),
        ],
      ),
    ),
  );

  group('the real adapters behind the seams', () {
    tearDown(getIt.reset);

    test('saveCheckInText reports failure rather than throwing', () async {
      // No journal stack registered: the static path logs and returns null,
      // and the adapter must translate that into "not saved" rather than
      // letting the composer think it succeeded.
      getIt.registerSingleton<DomainLogger>(MockDomainLogger());

      expect(
        await saveCheckInText(
          text: 'Walked.',
          goalEntryId: 'goal-1',
          started: now,
          timeSpent: const Duration(minutes: 3),
        ),
        isFalse,
      );
    });
  });

  testWidgets('names the goal and the moment', (tester) async {
    await pump(tester);
    // The frame that lands the resolved capture target rebuilds the header,
    // and the header formats `clock.now()` on every build — so this pump has
    // to run under the fixed clock too, or the month tracks the wall calendar
    // (the test rolled over on 1 September).
    await withClock(Clock.fixed(now), tester.pump);

    expect(find.text('Check in · Fitness'), findsOneWidget);
    expect(find.textContaining('August 18, 2026'), findsOneWidget);
  });

  testWidgets('opens on the recorder, not on a keyboard', (tester) async {
    await pump(tester);
    await tester.pump();

    // One tap, no typing, is the entire point.
    expect(find.byKey(const ValueKey('goal-checkin-record')), findsOneWidget);
    expect(find.byType(DesignSystemTextarea), findsNothing);
  });

  testWidgets('recording is withheld until the goal row exists', (
    tester,
  ) async {
    await pump(tester, captureTarget: null);
    await tester.pump();

    // Linking to a row that has not been written saves the recording and
    // silently drops the link, so the beat would never appear.
    final button = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('goal-checkin-record')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Write instead swaps the recorder for a textarea', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();

    await tester.tap(find.text('Write instead'));
    await tester.pump();

    expect(find.byType(DesignSystemTextarea), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-checkin-record')), findsNothing);
    // And back again — the fallback is a toggle, not a one-way door.
    expect(find.text('Record a check-in'), findsWidgets);
  });

  testWidgets("the prepared line is shown as the agent's, not as fact", (
    tester,
  ) async {
    await pump(
      tester,
      preparedLine: 'You said you would walk after lunch. It is 14:20.',
      personaName: 'Juno',
    );
    await tester.pump();

    expect(
      find.text('You said you would walk after lunch. It is 14:20.'),
      findsOneWidget,
    );
    // Provenance is explicit: the user is never answering a prompt without
    // knowing whose it is.
    expect(find.text('Juno · prepared for you'), findsOneWidget);
  });

  testWidgets('recording links to the goal row it was given', (tester) async {
    await pump(tester);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('goal-checkin-record')));
    await tester.pumpAndSettle();

    // The link is what puts the recording on the timeline — and, because the
    // recorder's stop path transcribes goal-linked audio, into the pipeline.
    expect(recorded, ['goal-1']);
    // The composer's job ended with the recording; it closes itself.
    expect(find.byType(GoalCheckInComposer), findsNothing);
  });

  testWidgets('discarding a recording returns to the composer', (tester) async {
    recorderResult = null;
    await pump(tester);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('goal-checkin-record')));
    await tester.pump();

    expect(recorded, ['goal-1']);
    expect(find.byType(GoalCheckInComposer), findsOneWidget);
  });

  testWidgets('a written check-in saves its text against the goal', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Write instead'));
    await tester.pump();

    await tester.enterText(
      find.byType(DesignSystemTextarea),
      '  Gym bag is packed.  ',
    );
    await tester.tap(find.text('Save check-in'));
    await tester.pump();

    expect(saved, hasLength(1));
    // Trimmed: the surrounding whitespace is an artifact of typing, not part
    // of what the user said.
    expect(saved.single.text, 'Gym bag is packed.');
    expect(saved.single.goalEntryId, 'goal-1');
  });

  testWidgets('an empty written check-in saves nothing', (tester) async {
    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Write instead'));
    await tester.pump();

    await tester.enterText(find.byType(DesignSystemTextarea), '   ');
    await tester.tap(find.text('Save check-in'));
    await tester.pump();

    expect(saved, isEmpty);
  });

  testWidgets('a failed save keeps the composer open with the text intact', (
    tester,
  ) async {
    saveSucceeds = false;
    await pump(tester);
    await tester.pump();
    await tester.tap(find.text('Write instead'));
    await tester.pump();

    await tester.enterText(find.byType(DesignSystemTextarea), 'Walked.');
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    // Closing on failure would discard what the user just wrote.
    expect(find.byType(GoalCheckInComposer), findsOneWidget);
    expect(find.text('Walked.'), findsOneWidget);
  });

  testWidgets('Close dismisses record mode without implying a save', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();

    expect(find.text('Save check-in'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Record mode has one primary CTA; Close is an unambiguous dismissal.
    expect(saved, isEmpty);
    expect(find.byType(GoalCheckInComposer), findsNothing);
  });

  testWidgets('no prepared line renders no empty card', (tester) async {
    await pump(tester);
    await tester.pump();

    // An absent prompt is normal; capture is the job, the prompt is additive.
    expect(find.textContaining('prepared for you'), findsNothing);
  });

  group('the writing session', () {
    // A clock the test moves by hand. The composer reads it on every tap and
    // on every tick, so each step below runs inside it.
    late DateTime current;
    late Clock movable;

    setUp(() {
      current = now;
      movable = Clock(() => current);
    });

    Future<void> elapse(WidgetTester tester, Duration by) async {
      current = current.add(by);
      // The ticker only repaints; one tick is enough to read the new time.
      await tester.pump(const Duration(seconds: 1));
    }

    String sessionLabel(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('goal-checkin-session-label')))
        .data!;

    Future<void> startWriting(WidgetTester tester) async {
      await tester.pump();
      await tester.tap(find.text('Write instead'));
      await tester.pump();
    }

    Future<void> saveText(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(DesignSystemTextarea), text);
      await tester.tap(find.text('Save check-in'));
      await tester.pump();
    }

    testWidgets('stores the time spent writing, from when writing began', (
      tester,
    ) async {
      await withClock(movable, () async {
        await pump(tester, clockOverride: movable);
        // Time spent looking at the recorder is not time spent writing.
        await elapse(tester, const Duration(minutes: 4));
        await startWriting(tester);

        await elapse(tester, const Duration(minutes: 2, seconds: 30));
        expect(sessionLabel(tester), 'Reflecting · 2:30');

        await saveText(tester, 'Gym bag is packed.');
      });

      expect(saved.single.started, now.add(const Duration(minutes: 4)));
      expect(saved.single.timeSpent, const Duration(minutes: 2, seconds: 30));
    });

    testWidgets('a paused session stops counting until resumed', (
      tester,
    ) async {
      await withClock(movable, () async {
        await pump(tester, clockOverride: movable);
        await startWriting(tester);
        await elapse(tester, const Duration(minutes: 1));

        await tester.tap(find.text('Pause'));
        await tester.pump();
        await elapse(tester, const Duration(minutes: 5));
        expect(sessionLabel(tester), 'Paused · 1:00');

        await tester.tap(find.text('Resume'));
        await tester.pump();
        await elapse(tester, const Duration(seconds: 30));
        expect(sessionLabel(tester), 'Reflecting · 1:30');

        await saveText(tester, 'Walked.');
      });

      expect(saved.single.timeSpent, const Duration(minutes: 1, seconds: 30));
    });

    testWidgets('a time set by hand replaces the counted time', (
      tester,
    ) async {
      await withClock(movable, () async {
        await pump(
          tester,
          clockOverride: movable,
          pickedDuration: const Duration(minutes: 5),
        );
        await startWriting(tester);
        await elapse(tester, const Duration(seconds: 40));

        await tester.tap(find.text('Edit time'));
        await tester.pump();
        expect(sessionLabel(tester), 'Time spent · 5 min');
        // The user's number is final: no clock left to pause.
        expect(find.text('Pause'), findsNothing);

        await elapse(tester, const Duration(minutes: 3));
        await saveText(tester, 'Walked.');
      });

      expect(saved.single.timeSpent, const Duration(minutes: 5));
    });

    testWidgets('a time set to zero by hand reads as zero minutes', (
      tester,
    ) async {
      await withClock(movable, () async {
        await pump(
          tester,
          clockOverride: movable,
          pickedDuration: Duration.zero,
        );
        await startWriting(tester);
        await tester.tap(find.text('Edit time'));
        await tester.pump();
        expect(sessionLabel(tester), 'Time spent · 0 min');
        await saveText(tester, 'Walked.');
      });

      expect(saved.single.timeSpent, Duration.zero);
    });

    testWidgets('backing out of the picker keeps the clock running', (
      tester,
    ) async {
      await withClock(movable, () async {
        await pump(tester, clockOverride: movable);
        await startWriting(tester);
        await elapse(tester, const Duration(minutes: 1));

        await tester.tap(find.text('Edit time'));
        await tester.pump();
        await elapse(tester, const Duration(minutes: 1));
        expect(sessionLabel(tester), 'Reflecting · 2:00');
      });
    });

    testWidgets('switching to the recorder stops the writing clock', (
      tester,
    ) async {
      await withClock(movable, () async {
        await pump(tester, clockOverride: movable);
        await startWriting(tester);
        await elapse(tester, const Duration(minutes: 1));

        // The recorder's own span is a voice check-in's time.
        await tester.tap(find.text('Record a check-in').last);
        await tester.pump();
        await elapse(tester, const Duration(minutes: 10));

        await tester.tap(find.text('Write instead'));
        await tester.pump();
        await elapse(tester, const Duration(minutes: 1));
        expect(sessionLabel(tester), 'Reflecting · 2:00');

        await saveText(tester, 'Walked.');
      });

      // The session still began when writing first began.
      expect(saved.single.started, now);
      expect(saved.single.timeSpent, const Duration(minutes: 2));
    });
  });
}
