import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_composer.dart';
import 'package:lotti/features/speech/state/app_settings_opener.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_failure_callout.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../relationships/helpers/check_in_speech_fakes.dart';

void main() {
  final now = DateTime(2026, 8, 18, 14, 20);

  late List<
    ({String text, String goalEntryId, DateTime started, Duration timeSpent})
  >
  saved;

  /// The category every written save was filed under.
  late List<String?> filedUnder;
  late FakeAudioRecorderController recorder;
  var saveSucceeds = true;
  var settingsOpened = 0;

  /// When set, a save waits for it before it answers.
  Completer<void>? saveGate;

  setUp(() {
    saved = [];
    filedUnder = [];
    saveSucceeds = true;
    saveGate = null;
    settingsOpened = 0;
    recorder = FakeAudioRecorderController();
  });

  Future<void> pump(
    WidgetTester tester, {
    String? captureTarget = 'goal-1',
    String? preparedLine,
    Clock? clockOverride,
    Duration? pickedDuration,
    String? hostCategory = 'cat-1',
    String? goalRowCategory,
    GoalCheckInStart start = GoalCheckInStart.idle,
    Future<String?> Function()? captureTargetRead,
    Future<String?> Function()? goalRowCategoryRead,
  }) => withClock(
    clockOverride ?? Clock.fixed(now),
    () => tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        GoalCheckInComposer(
          agentId: 'agent-1',
          goalTitle: 'Fitness',
          start: start,
          preparedLine: preparedLine,
          categoryId: hostCategory,
          saveText:
              ({
                required text,
                required goalEntryId,
                required started,
                required timeSpent,
                categoryId,
              }) async {
                filedUnder.add(categoryId);
                saved.add((
                  text: text,
                  goalEntryId: goalEntryId,
                  started: started,
                  timeSpent: timeSpent,
                ));
                await saveGate?.future;
                return saveSucceeds;
              },
          pickDuration: ({required context, required initialDuration}) async =>
              pickedDuration,
        ),
        overrides: [
          goalCaptureTargetProvider('agent-1').overrideWith(
            (ref) => captureTargetRead != null
                ? captureTargetRead()
                : Future.value(captureTarget),
          ),
          goalCategoryIdProvider(
            'agent-1',
          ).overrideWith(
            (ref) => goalRowCategoryRead != null
                ? goalRowCategoryRead()
                : Future.value(goalRowCategory),
          ),
          audioRecorderControllerProvider.overrideWith(() => recorder),
          appSettingsOpenerProvider.overrideWithValue(() async {
            settingsOpened++;
            return true;
          }),
        ],
      ),
    ),
  );

  /// Lets the capture target resolve and the recorder start, frame by frame:
  /// while a take is live the visualizer keeps moving, so nothing settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  /// Opens the composer on a route of its own, as the app does, so a test
  /// can tell that it closed. Returns how many times it has closed.
  Future<int Function()> pumpOnRoute(
    WidgetTester tester, {
    GoalCheckInStart start = GoalCheckInStart.idle,
  }) async {
    var closed = 0;
    await withClock(
      Clock.fixed(now),
      () => tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: GoalCheckInComposer(
                      agentId: 'agent-1',
                      goalTitle: 'Fitness',
                      categoryId: 'cat-1',
                      start: start,
                    ),
                  ),
                );
                closed++;
              },
              child: const Text('open'),
            ),
          ),
          overrides: [
            goalCaptureTargetProvider(
              'agent-1',
            ).overrideWith((ref) async => 'goal-1'),
            goalCategoryIdProvider('agent-1').overrideWith((ref) async => null),
            audioRecorderControllerProvider.overrideWith(() => recorder),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return () => closed;
  }

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

  group('speaking', () {
    testWidgets('opened from Speak it is already recording: one sheet, no '
        'second tap, linked to the goal and left to the recorder to '
        'transcribe', (tester) async {
      await pump(
        tester,
        start: GoalCheckInStart.speaking,
        preparedLine: 'What got in the way on Tuesday?',
      );
      await settle(tester);

      expect(recorder.recordCalls, [
        (linkedId: 'goal-1', handledByCaller: false),
      ]);
      expect(recorder.categoryIds, ['cat-1']);
      expect(find.byType(InlineRecorder), findsOneWidget);
      // The question being answered stays in view while recording.
      expect(find.text('What got in the way on Tuesday?'), findsOneWidget);
      // The red Stop pill says it is recording; no second line repeats it.
      expect(key('check-in-recorder-status'), findsNothing);
      expect(find.text('Recording'), findsNothing);
      // The recorder's own row is the only set of controls.
      expect(key('goal-checkin-mode-toggle'), findsNothing);
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('Stop saves the take, says so and closes the sheet', (
      tester,
    ) async {
      final closed = await pumpOnRoute(
        tester,
        start: GoalCheckInStart.speaking,
      );

      await tester.tap(key('stop_recording'));
      await settle(tester);

      expect(recorder.stopCalls, 1);
      expect(closed(), 1);
      expect(find.byType(GoalCheckInComposer), findsNothing);
      expect(find.text('Check-in saved'), findsOneWidget);
    });

    testWidgets('it waits for the goal row and its category, then records '
        'under the goal row category', (tester) async {
      await pump(
        tester,
        start: GoalCheckInStart.speaking,
        hostCategory: null,
        goalRowCategory: 'colony-fitness',
      );
      // Before either lookup lands: a spinner, and no recording yet.
      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      expect(recorder.recordCalls, isEmpty);

      await settle(tester);
      expect(recorder.categoryIds, ['colony-fitness']);
      expect(recorder.recordCalls, hasLength(1));
    });

    testWidgets('with no goal row to record into it rests, Speak disabled, '
        'and never records', (tester) async {
      await pump(tester, start: GoalCheckInStart.speaking, captureTarget: null);
      await settle(tester);

      // Linking to a row that has not been written saves the recording and
      // silently drops the link, so the beat would never appear.
      expect(recorder.recordCalls, isEmpty);
      expect(
        tester.widget<DesignSystemButton>(key('goal-checkin-record')).onPressed,
        isNull,
      );
    });

    testWidgets('a discarded take returns to the sheet at rest', (
      tester,
    ) async {
      await pump(tester, start: GoalCheckInStart.speaking);
      await settle(tester);

      await tester.tap(key('cancel_recording'));
      await settle(tester);
      await tester.tap(find.text('Discard').last);
      await settle(tester);

      expect(recorder.cancelCalls, 1);
      expect(find.byType(GoalCheckInComposer), findsOneWidget);
      expect(find.byType(InlineRecorder), findsNothing);
      // The user may still want to speak again, or write instead.
      expect(key('goal-checkin-record'), findsOneWidget);
      expect(find.text('Write instead'), findsOneWidget);
    });

    testWidgets('a refused microphone says so, with Open settings and Write '
        'instead — and Speak right there to try again', (tester) async {
      recorder = FakeAudioRecorderController(
        recordFailure: AudioRecordingFailure.permissionDenied,
      );
      await pump(tester, start: GoalCheckInStart.speaking);
      await settle(tester);

      expect(find.text('Allow microphone access'), findsOneWidget);
      expect(find.textContaining('then tap Speak'), findsOneWidget);
      // The slashed mic belongs here: the microphone IS unavailable.
      expect(
        find.descendant(
          of: key('recording-failure-microphoneDenied'),
          matching: find.byIcon(LottiIcons.micIdle),
        ),
        findsOneWidget,
      );
      // One Write instead, in the callout — not a second under it.
      expect(find.text('Write instead'), findsOneWidget);

      await tester.tap(find.byKey(RecordingFailureCallout.openSettingsKey));
      expect(settingsOpened, 1);

      // Speak tries again, and the failure is cleared while it does.
      recorder.recordFailure = null;
      await tester.tap(key('goal-checkin-record'));
      await settle(tester);
      expect(find.text('Allow microphone access'), findsNothing);
      expect(find.byType(InlineRecorder), findsOneWidget);
    });

    testWidgets("someone else's running take is never taken over: the sheet "
        'says a recording is already running', (tester) async {
      recorder = FakeAudioRecorderController(runningFor: 'another-goal');
      await pump(tester, start: GoalCheckInStart.speaking);
      await settle(tester);

      expect(find.text('A recording is already running'), findsOneWidget);
      expect(recorder.recordCalls, isEmpty);
      expect(recorder.stopCalls, 0);
      // No settings door: the microphone is fine.
      expect(find.byKey(RecordingFailureCallout.openSettingsKey), findsNothing);
    });

    testWidgets('the running take can be stopped from the callout — a '
        "phone's goal page has no recording indicator to stop it from — and "
        'then Speak records', (tester) async {
      recorder = FakeAudioRecorderController(runningFor: 'another-goal');
      await pump(tester, start: GoalCheckInStart.speaking);
      await settle(tester);

      // Says where the stopped take goes, not to look for an indicator.
      expect(find.textContaining('saved where it was started'), findsOneWidget);
      await tester.tap(find.byKey(RecordingFailureCallout.stopRunningKey));
      await settle(tester);

      // Stopped, which saves it under its own subject; never `record`, which
      // would have filed it under this goal.
      expect(recorder.stopCalls, 1);
      expect(recorder.recordCalls, isEmpty);
      expect(find.text('A recording is already running'), findsNothing);

      await tester.tap(key('goal-checkin-record'));
      await settle(tester);
      expect(recorder.recordCalls, [
        (linkedId: 'goal-1', handledByCaller: false),
      ]);
    });

    testWidgets('a running take that could not be saved on stop says so', (
      tester,
    ) async {
      recorder = FakeAudioRecorderController(
        runningFor: 'another-goal',
        stopResult: null,
      );
      await pump(tester, start: GoalCheckInStart.speaking);
      await settle(tester);

      await tester.tap(find.byKey(RecordingFailureCallout.stopRunningKey));
      await settle(tester);

      expect(find.text("Recording couldn't be saved"), findsOneWidget);
    });

    testWidgets('a goal row that could not be read says so with Try again, '
        'never an endless spinner — and a retry that lands does not turn '
        'the mic on by itself', (tester) async {
      var fail = true;
      var reads = 0;
      await pump(
        tester,
        start: GoalCheckInStart.speaking,
        captureTargetRead: () async {
          reads++;
          if (fail) throw StateError('journal gone');
          return 'goal-1';
        },
      );
      await settle(tester);

      expect(key('goal-checkin-target-failed'), findsOneWidget);
      expect(find.byType(DesignSystemSpinner), findsNothing);
      expect(recorder.recordCalls, isEmpty);

      fail = false;
      final before = reads;
      await tester.tap(key('goal-checkin-target-retry'));
      await settle(tester);

      expect(reads, greaterThan(before));
      expect(key('goal-checkin-target-failed'), findsNothing);
      // At rest: the user reads an error, then decides to speak.
      expect(recorder.recordCalls, isEmpty);
      expect(
        tester.widget<DesignSystemButton>(key('goal-checkin-record')).onPressed,
        isNotNull,
      );
    });

    for (final (name, arrange, title) in <(String, void Function(), String)>[
      (
        'a start that failed',
        () => recorder = FakeAudioRecorderController(
          recordFailure: AudioRecordingFailure.startFailed,
        ),
        "Recording didn't start",
      ),
      (
        'a take that could not be saved',
        () => recorder = FakeAudioRecorderController(stopResult: null),
        "Recording couldn't be saved",
      ),
    ]) {
      testWidgets('$name says so, and writing is the way that still works', (
        tester,
      ) async {
        arrange();
        await pump(tester, start: GoalCheckInStart.speaking);
        await settle(tester);
        if (find.byType(InlineRecorder).evaluate().isNotEmpty) {
          await tester.tap(key('stop_recording'));
          await settle(tester);
        }

        expect(find.text(title), findsOneWidget);
        await tester.tap(key('goal-checkin-failure-write'));
        await tester.pump();
        expect(find.byType(DesignSystemTextarea), findsOneWidget);
        expect(find.text(title), findsNothing);
      });
    }
  });

  testWidgets('opened from a banner it rests: the mic is not turned on for '
      'the user, and Speak is one tap away', (tester) async {
    await pump(tester);
    await settle(tester);

    expect(recorder.recordCalls, isEmpty);
    expect(find.byType(DesignSystemTextarea), findsNothing);
    final speak = tester.widget<DesignSystemButton>(key('goal-checkin-record'));
    expect(speak.label, 'Speak');
    expect(speak.leadingIcon, LottiIcons.mic);

    await tester.tap(key('goal-checkin-record'));
    await settle(tester);
    expect(recorder.recordCalls, hasLength(1));
  });

  testWidgets('recording is withheld until the goal row exists', (
    tester,
  ) async {
    await pump(tester, captureTarget: null);
    await tester.pump();

    final button = tester.widget<DesignSystemButton>(
      key('goal-checkin-record'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Write instead swaps Speak for a textarea, and Speak instead '
      'is the way back', (tester) async {
    await pump(tester);
    await tester.pump();

    await tester.tap(find.text('Write instead'));
    await tester.pump();

    expect(find.byType(DesignSystemTextarea), findsOneWidget);
    expect(key('goal-checkin-record'), findsNothing);
    // And back again — the fallback is a toggle, not a one-way door.
    expect(find.text('Speak instead'), findsOneWidget);
  });

  testWidgets('opened to write, the text field is up at once', (tester) async {
    await pump(tester, start: GoalCheckInStart.writing);
    await tester.pump();

    expect(find.byType(DesignSystemTextarea), findsOneWidget);
    expect(recorder.recordCalls, isEmpty);
  });

  testWidgets("the prepared line is shown as the agent's, in the agent's "
      'violet, not as fact', (tester) async {
    await pump(
      tester,
      preparedLine: 'You said you would walk after lunch. It is 14:20.',
    );
    await tester.pump();

    expect(
      find.text('You said you would walk after lunch. It is 14:20.'),
      findsOneWidget,
    );
    // Provenance is the agent's own card — its violet — and nothing more:
    // no line of copy over the recorder saying who prepared it.
    final card = tester.widget<DecoratedBox>(key('goal-checkin-prepared'));
    expect(
      card.decoration,
      aiCardDecoration(tester.element(key('goal-checkin-prepared'))),
    );
    expect(
      find.descendant(
        of: key('goal-checkin-prepared'),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets("opened before the host knew the goal's category, a note is "
      'filed under the goal row category', (tester) async {
    await pump(tester, hostCategory: null, goalRowCategory: 'colony-fitness');
    await tester.pump();
    await tester.tap(find.text('Write instead'));
    await tester.pump();
    await tester.enterText(find.byType(DesignSystemTextarea), 'Waddled.');
    await tester.tap(find.text('Save check-in'));
    await tester.pump();

    expect(filedUnder, ['colony-fitness']);
  });

  testWidgets("a note cannot be saved before the goal's category has "
      'read — it would be filed uncategorized for good', (tester) async {
    final category = Completer<String?>();
    await pump(
      tester,
      hostCategory: null,
      goalRowCategoryRead: () => category.future,
      start: GoalCheckInStart.writing,
    );
    await tester.pump();
    await tester.enterText(find.byType(DesignSystemTextarea), 'Waddled.');
    await tester.pump();

    DesignSystemButton save() =>
        tester.widget<DesignSystemButton>(key('goal-checkin-save'));
    expect(save().onPressed, isNull);

    category.complete('colony-fitness');
    await tester.pump();
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text('Save check-in'));
    await tester.pump();
    expect(filedUnder, ['colony-fitness']);
  });

  testWidgets('a category lookup that failed does not hold the sheet: the '
      'note saves, uncategorized', (tester) async {
    await pump(
      tester,
      hostCategory: null,
      goalRowCategoryRead: () async => throw StateError('journal gone'),
      start: GoalCheckInStart.writing,
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(DesignSystemTextarea), 'Waddled.');
    await tester.tap(find.text('Save check-in'));
    await tester.pump();

    expect(filedUnder, [null]);
  });

  testWidgets("the host's category, when it has one, is the one used", (
    tester,
  ) async {
    await pump(tester, goalRowCategory: 'colony-fitness');
    await tester.pump();
    await tester.tap(find.text('Write instead'));
    await tester.pump();
    await tester.enterText(find.byType(DesignSystemTextarea), 'Waddled.');
    await tester.tap(find.text('Save check-in'));
    await tester.pump();

    expect(filedUnder, ['cat-1']);
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

  testWidgets('while a save is pending nothing else can open or start: '
      'no time picker over it, no take behind it', (tester) async {
    final gate = Completer<void>();
    saveGate = gate;
    await pump(tester, start: GoalCheckInStart.writing);
    await tester.pump();
    await tester.enterText(find.byType(DesignSystemTextarea), 'Walked.');
    await tester.tap(find.text('Save check-in'));
    await tester.pump();

    DesignSystemButton button(String name) =>
        tester.widget<DesignSystemButton>(key(name));
    expect(button('goal-checkin-mode-toggle').onPressed, isNull);
    expect(button('goal-checkin-session-edit').onPressed, isNull);
    expect(button('goal-checkin-session-toggle').onPressed, isNull);

    // A failed save hands them back, the draft intact.
    saveSucceeds = false;
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(button('goal-checkin-mode-toggle').onPressed, isNotNull);
    expect(button('goal-checkin-session-edit').onPressed, isNotNull);
    expect(find.text('Walked.'), findsOneWidget);
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

  testWidgets('at rest Close is a plain way out, never a save', (
    tester,
  ) async {
    final closed = await pumpOnRoute(tester);

    // At rest Speak is the one primary; Close is an unambiguous dismissal.
    expect(find.text('Save check-in'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(closed(), 1);
    expect(saved, isEmpty);
    expect(recorder.recordCalls, isEmpty);
    expect(find.byType(GoalCheckInComposer), findsNothing);
  });

  testWidgets('no prepared line renders no empty card', (tester) async {
    await pump(tester);
    await tester.pump();

    // An absent prompt is normal; capture is the job, the prompt is additive.
    expect(key('goal-checkin-prepared'), findsNothing);
  });

  group('opened as a sheet', () {
    var recordersBuilt = 0;
    setUp(() => recordersBuilt = 0);

    Future<void> openSheet(WidgetTester tester, GoalCheckInStart start) async {
      await withClock(
        Clock.fixed(now),
        () => tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => GoalCheckInComposer.show(
                  context,
                  agentId: 'agent-1',
                  goalTitle: 'Fitness',
                  start: start,
                  categoryId: 'cat-1',
                ),
                child: const Text('open'),
              ),
            ),
            overrides: [
              goalCaptureTargetProvider(
                'agent-1',
              ).overrideWith((ref) async => 'goal-1'),
              goalCategoryIdProvider(
                'agent-1',
              ).overrideWith((ref) async => null),
              audioRecorderControllerProvider.overrideWith(() {
                recordersBuilt++;
                return recorder;
              }),
            ],
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('dismissed mid-take, the take keeps running and goes back '
        'to the recording strip, where it can be stopped', (tester) async {
      await openSheet(tester, GoalCheckInStart.speaking);
      // The sheet is titled with the goal, so the recorder is never
      // anonymous and no second line has to name it.
      expect(find.text('Fitness'), findsOneWidget);
      expect(recorder.inlineHostVisibleLog.last, isTrue);

      Navigator.of(tester.element(find.byType(GoalCheckInComposer))).pop();
      await settle(tester);

      expect(find.byType(GoalCheckInComposer), findsNothing);
      expect(recorder.stopCalls, 0);
      expect(recorder.cancelCalls, 0);
      expect(recorder.inlineHostVisibleLog.last, isFalse);
    });

    testWidgets('a written check-in never stands the recorder up', (
      tester,
    ) async {
      await openSheet(tester, GoalCheckInStart.writing);
      expect(find.byType(DesignSystemTextarea), findsOneWidget);

      Navigator.of(tester.element(find.byType(GoalCheckInComposer))).pop();
      await settle(tester);

      expect(recordersBuilt, 0);
    });
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

        // The recorder's own span is a voice check-in's time. Here the take
        // never starts, so the sheet comes back at rest with the reason.
        recorder.recordFailure = AudioRecordingFailure.startFailed;
        await tester.tap(find.text('Speak instead'));
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
