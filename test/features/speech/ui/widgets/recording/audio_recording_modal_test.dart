import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';
import 'package:lotti/features/speech/state/app_settings_opener.dart';
import 'package:lotti/features/speech/state/checkbox_visibility_provider.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/features/speech/ui/widgets/recording/audio_recording_modal.dart';
import 'package:lotti/features/speech/ui/widgets/recording/inline_recorder.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_controls.dart';
import 'package:lotti/features/speech/ui/widgets/recording/recording_failure_callout.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';
import '../../../../relationships/helpers/check_in_speech_fakes.dart';

const _taskId = 'task-1';
const _categoryId = 'category-7';

void main() {
  late FakeAudioRecorderController recorder;
  late MockJournalDb journalDb;
  late MockNavService navService;
  final results = <String?>[];
  var settingsOpened = 0;

  setUp(() async {
    recorder = FakeAudioRecorderController();
    journalDb = MockJournalDb();
    navService = MockNavService();
    results.clear();
    settingsOpened = 0;
    when(() => journalDb.journalEntityById(any())).thenAnswer(
      (_) async => testTask,
    );
    when(() => navService.beamToNamed(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<NavService>(navService),
    );
  });
  tearDown(tearDownTestGetIt);

  /// A live take never settles: pump a bounded while instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Opens the sheet the way the app does, from a button on a page.
  Future<void> open(
    WidgetTester tester, {
    String? linkedId = _taskId,
    String? categoryId = _categoryId,
    bool transcriptionHandledByCaller = false,
    bool openCreatedEntry = true,
    AutomaticPromptVisibility visibility = const AutomaticPromptVisibility(
      speech: true,
    ),
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await AudioRecordingModal.show(
                context,
                linkedId: linkedId,
                categoryId: categoryId,
                transcriptionHandledByCaller: transcriptionHandledByCaller,
                openCreatedEntry: openCreatedEntry,
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: [
          audioRecorderControllerProvider.overrideWith(() => recorder),
          journalDbProvider.overrideWithValue(journalDb),
          checkboxVisibilityProvider((
            categoryId: categoryId,
            linkedId: linkedId,
          )).overrideWithValue(visibility),
          appSettingsOpenerProvider.overrideWithValue(() async {
            settingsOpened++;
            return true;
          }),
          ...overrides,
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Finder key(Key key) => find.byKey(key);
  const recordKey = ValueKey('record');
  const transcribeKey = Key('speech_recognition_checkbox');

  group('recordingSubjectTitle', () {
    final meta = testTextEntry.meta;
    for (final (name, subject, expected) in <(String, JournalEntity?, String?)>[
      ('a task is its title', testTask, testTask.data.title),
      (
        'an entry is its words, trimmed',
        JournalEntity.journalEntry(
          meta: meta,
          entryText: const EntryText(plainText: '  Call the vet  '),
        ),
        'Call the vet',
      ),
      (
        'an entry with no words is nothing',
        JournalEntity.journalEntry(
          meta: meta,
          entryText: const EntryText(plainText: '   '),
        ),
        null,
      ),
      (
        'an entry with no text at all is nothing',
        JournalEntry(meta: meta),
        null,
      ),
      ('no subject is nothing', null, null),
    ]) {
      test(name, () => expect(recordingSubjectTitle(subject), expected));
    }
  });

  testWidgets('opens already recording — no second tap — for its subject and '
      'category, titled with what the recording is about', (tester) async {
    await open(tester);

    expect(recorder.recordCalls, [(linkedId: _taskId, handledByCaller: false)]);
    expect(recorder.categoryIds.toSet(), {_categoryId});
    expect(find.text(testTask.data.title), findsOneWidget);
    expect(find.byType(RecordingTransportControls), findsOneWidget);
    expect(key(recordKey), findsNothing);
    // The floating indicator is hidden while the sheet shows the take.
    expect(recorder.modalVisibleLog, isNotEmpty);
    expect(recorder.modalVisibleLog, everyElement(isTrue));
  });

  testWidgets('Stop saves the take, closes the sheet with its id, and hands '
      'the floating indicator back', (tester) async {
    recorder.stopResult = 'audio-42';
    await open(tester);

    await tester.tap(key(RecordingTransportControls.stopKey));
    await settle(tester);

    expect(results, ['audio-42']);
    expect(find.byType(AudioRecordingModalContent), findsNothing);
    expect(recorder.modalVisibleLog.last, isFalse);
    // Linked to its subject: the user stays where they are.
    verifyNever(() => navService.beamToNamed(any()));
  });

  for (final openCreatedEntry in [true, false]) {
    testWidgets('a recording with no subject has the plain title and opens '
        'as its own entry once saved — unless the caller links it itself: '
        'openCreatedEntry $openCreatedEntry', (tester) async {
      await open(
        tester,
        linkedId: null,
        categoryId: null,
        openCreatedEntry: openCreatedEntry,
      );
      expect(find.text('Record a voice note'), findsOneWidget);
      expect(recorder.recordCalls, [(linkedId: null, handledByCaller: false)]);
      verifyNever(() => journalDb.journalEntityById(any()));

      await tester.tap(key(RecordingTransportControls.stopKey));
      await settle(tester);

      expect(results, ['audio-1']);
      if (openCreatedEntry) {
        verify(() => navService.beamToNamed('/journal/audio-1')).called(1);
      } else {
        verifyNever(() => navService.beamToNamed(any()));
      }
    });
  }

  testWidgets('a subject that cannot be read costs only its name: the sheet '
      'opens under the plain title and records all the same', (tester) async {
    when(
      () => journalDb.journalEntityById(any()),
    ).thenThrow(StateError('database closed'));
    await open(tester);

    expect(find.text('Record a voice note'), findsOneWidget);
    expect(recorder.recordCalls.single.linkedId, _taskId);
  });

  group('Transcribe', () {
    testWidgets('where a transcription would run it is offered under the '
        'controls, on unless switched off, and the switch reaches the '
        'recorder', (tester) async {
      await open(tester);

      final option = tester.widget<RecordingOption>(key(transcribeKey));
      expect(option.label, 'Transcribe');
      expect(option.value, isTrue);
      expect(
        tester.getRect(key(transcribeKey)).top,
        greaterThan(
          tester.getRect(find.byType(RecordingTransportControls)).bottom,
        ),
      );

      await tester.tap(key(transcribeKey));
      await tester.pump();
      expect(recorder.state.enableSpeechRecognition, isFalse);
      expect(
        tester.widget<RecordingOption>(key(transcribeKey)).value,
        isFalse,
      );
    });

    testWidgets('where nothing would transcribe it is not offered', (
      tester,
    ) async {
      await open(
        tester,
        visibility: const AutomaticPromptVisibility(speech: false),
      );
      expect(key(transcribeKey), findsNothing);
    });

    testWidgets('a recording filed nowhere and linked to nothing has no '
        'automation to offer', (tester) async {
      await open(tester, linkedId: null, categoryId: null);
      expect(key(transcribeKey), findsNothing);
    });

    testWidgets('a caller that transcribes the take itself gets no option, '
        'and the recorder is told so from the start', (tester) async {
      await open(tester, transcriptionHandledByCaller: true);

      expect(key(transcribeKey), findsNothing);
      expect(recorder.recordCalls, [
        (linkedId: _taskId, handledByCaller: true),
      ]);
    });
  });

  testWidgets('a confirmed discard closes the sheet with nothing', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(key(RecordingTransportControls.discardKey));
    await settle(tester);
    expect(
      find.textContaining('This recording will be deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Discard').last);
    await settle(tester);

    expect(recorder.cancelCalls, 1);
    expect(recorder.stopCalls, 0);
    expect(results, [null]);
    expect(find.byType(AudioRecordingModalContent), findsNothing);
  });

  testWidgets('dismissed mid-take, the take keeps running and goes back to '
      'the floating indicator, where it can be stopped', (tester) async {
    await open(tester);

    Navigator.of(
      tester.element(find.byType(AudioRecordingModalContent)),
    ).pop();
    await settle(tester);

    expect(results, [null]);
    expect(recorder.stopCalls, 0);
    expect(recorder.cancelCalls, 0);
    expect(recorder.state.status, AudioRecorderStatus.recording);
    expect(recorder.modalVisibleLog.last, isFalse);
  });

  testWidgets('reopened for the subject whose take is running — the '
      "indicator's tap — it attaches: no second start, the running clock", (
    tester,
  ) async {
    recorder = FakeAudioRecorderController(runningFor: _taskId);
    await open(tester);
    recorder.tick(progress: const Duration(seconds: 83));
    await tester.pump();

    expect(recorder.recordCalls, isEmpty);
    expect(find.text('01:23'), findsOneWidget);
    expect(find.text(testTask.data.title), findsOneWidget);
  });

  group('a recorder that could not record', () {
    testWidgets('a refused microphone rests the sheet on its reason, with '
        'the door to settings, and Record tries again', (tester) async {
      recorder = FakeAudioRecorderController(
        recordFailure: AudioRecordingFailure.permissionDenied,
      );
      await open(tester);

      expect(find.byType(InlineRecorder), findsNothing);
      expect(find.text('Allow microphone access'), findsOneWidget);
      expect(
        find.textContaining("Lotti can't use the microphone."),
        findsOneWidget,
      );
      await tester.tap(key(RecordingFailureCallout.openSettingsKey));
      expect(settingsOpened, 1);

      // Allowed now: Record starts the take and the reason goes.
      recorder.recordFailure = null;
      await tester.tap(key(recordKey));
      await settle(tester);
      expect(find.text('Allow microphone access'), findsNothing);
      expect(find.byType(RecordingTransportControls), findsOneWidget);
      expect(recorder.recordCalls, hasLength(2));
    });

    testWidgets('a microphone that would not start says so, with no door '
        'to settings', (tester) async {
      recorder = FakeAudioRecorderController(
        recordFailure: AudioRecordingFailure.startFailed,
      );
      await open(tester);

      expect(find.text("Recording didn't start"), findsOneWidget);
      expect(key(RecordingFailureCallout.openSettingsKey), findsNothing);
      expect(key(RecordingFailureCallout.stopRunningKey), findsNothing);
      expect(key(recordKey), findsOneWidget);
    });

    testWidgets("someone else's running take is never taken over: it can be "
        'stopped from the sheet — saved where it was started — and then '
        'Record records', (tester) async {
      recorder = FakeAudioRecorderController(runningFor: 'another-task');
      await open(tester);

      expect(find.text('A recording is already running'), findsOneWidget);
      expect(recorder.recordCalls, isEmpty);
      expect(recorder.stopCalls, 0);

      await tester.tap(key(RecordingFailureCallout.stopRunningKey));
      await settle(tester);
      expect(recorder.stopCalls, 1);
      expect(find.text('A recording is already running'), findsNothing);
      // The sheet stays: stopping the other take is not this take's Stop.
      expect(results, isEmpty);

      await tester.tap(key(recordKey));
      await settle(tester);
      expect(recorder.recordCalls, [
        (linkedId: _taskId, handledByCaller: false),
      ]);
    });

    testWidgets('a running take that will not stop is said to be unsaved', (
      tester,
    ) async {
      recorder = FakeAudioRecorderController(
        runningFor: 'another-task',
        stopResult: null,
      );
      await open(tester);

      await tester.tap(key(RecordingFailureCallout.stopRunningKey));
      await settle(tester);

      expect(find.text("Recording couldn't be saved"), findsOneWidget);
    });

    testWidgets('a take that could not be saved keeps the sheet open on its '
        'reason rather than closing on nothing', (tester) async {
      recorder = FakeAudioRecorderController(stopResult: null);
      await open(tester);

      await tester.tap(key(RecordingTransportControls.stopKey));
      await settle(tester);

      expect(results, isEmpty);
      expect(find.text("Recording couldn't be saved"), findsOneWidget);
      expect(key(recordKey), findsOneWidget);
    });
  });
}
