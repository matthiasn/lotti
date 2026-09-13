import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_utils.dart';

/// One run of [CheckInTranscriptionService.transcribe] under fake time.
///
/// Wraps the whole call so no test ever waits on a real timer: [settle]
/// advances the clock, and [result]/[isDone] report where the wait got to.
class _Run {
  _Run(this._async, this._updates, this._wait) {
    _wait.result.then((value) {
      _isDone = true;
      _result = value;
    });
  }

  final FakeAsync _async;
  final StreamController<Set<String>> _updates;
  final CheckInTranscriptWait _wait;
  var _isDone = false;
  String? _result;

  bool get isDone => _isDone;
  String? get result => _result;
  bool get hasListener => _updates.hasListener;

  void cancel() {
    _wait.cancel();
    settle();
  }

  void notify(Set<String> affectedIds) {
    _updates.add(affectedIds);
    settle();
  }

  void failNotifications() {
    _updates.addError(StateError('notification stream failed'));
    settle();
  }

  void closeNotifications() {
    _updates.close().ignore();
    settle();
  }

  void settle([Duration by = Duration.zero]) {
    _async
      ..elapse(by)
      ..flushMicrotasks();
  }
}

void main() {
  late MockJournalDb journalDb;
  late MockProfileResolver resolver;
  late ResolvedProfile defaultProfile;
  late MockSkillInferenceRunner runner;

  const audioEntryId = 'audio-1';

  JournalAudio audioWith(String? transcript) => testAudioEntry.copyWith(
    entryText: transcript == null ? null : EntryText(plainText: transcript),
  );

  void stubEntity(JournalEntity? entity) {
    when(
      () => journalDb.journalEntityById(audioEntryId),
    ).thenAnswer((_) async => entity);
  }

  /// Runs [body] against a service whose stream lives inside the fake zone —
  /// a controller built outside it would never settle under `fakeAsync`.
  void withRun(void Function(_Run run) body) {
    fakeAsync((async) {
      final updates = StreamController<Set<String>>.broadcast();
      final notifications = MockUpdateNotifications();
      when(
        () => notifications.updateStream,
      ).thenAnswer((_) => updates.stream);
      final service = CheckInTranscriptionService(
        journalDb,
        notifications,
        resolver,
        runner,
      );

      final wait = service.transcribe(
        audioEntryId: audioEntryId,
      );
      final run = _Run(async, updates, wait)..settle();
      body(run);
      // Drain the deadline so fakeAsync does not report a pending timer.
      run.settle(checkInTranscriptTimeout);
      updates.close().ignore();
    });
  }

  setUpAll(() {
    registerFallbackValue(AutomationResult.notHandled);
    registerFallbackValue(SkillType.transcription);
  });

  ResolvedProfile profile({bool model = true, bool provider = true}) =>
      ResolvedProfile(
        thinkingModelId: 'thinking-model',
        thinkingProvider: testInferenceProvider(),
        transcriptionModelId: model ? 'selected-transcription-model' : null,
        transcriptionProvider: provider ? testInferenceProvider() : null,
      );

  void stubDefault(ResolvedProfile? value) {
    when(() => resolver.resolveDefaultProfile()).thenAnswer((_) async => value);
  }

  setUp(() {
    journalDb = MockJournalDb();
    resolver = MockProfileResolver();
    defaultProfile = profile();
    runner = MockSkillInferenceRunner();
    when(
      () => runner.runTranscription(
        audioEntryId: any(named: 'audioEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
        overrideModelId: any(named: 'overrideModelId'),
        geminiThinkingMode: any(named: 'geminiThinkingMode'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((_) async {});
    stubDefault(defaultProfile);
    stubEntity(audioWith(null));
  });

  test('notification stream failure ends the transcript wait', () {
    withRun((run) {
      run.failNotifications();
      expect(run.isDone, isTrue);
      expect(run.result, isNull);
      expect(run.hasListener, isFalse);
    });
  });

  test('closed notification stream ends the transcript wait', () {
    withRun((run) {
      run.closeNotifications();
      expect(run.isDone, isTrue);
      expect(run.result, isNull);
      expect(run.hasListener, isFalse);
    });
  });

  test('database read failure ends the wait without an unhandled error', () {
    when(() => journalDb.journalEntityById(audioEntryId)).thenAnswer(
      (_) async => throw StateError('database closed'),
    );
    withRun((run) {
      expect(run.isDone, isTrue);
      expect(run.result, isNull);
      expect(run.hasListener, isFalse);
    });
  });

  group('transcript already present', () {
    test('resolves on the first read, with no notification', () {
      stubEntity(audioWith('We talked about her job search.'));

      withRun((run) {
        expect(run.isDone, isTrue);
        expect(run.result, 'We talked about her job search.');
      });
    });

    test('trims surrounding whitespace', () {
      stubEntity(audioWith('  padded transcript \n'));

      withRun((run) => expect(run.result, 'padded transcript'));
    });
  });

  group('transcript arrives later', () {
    test('resolves on a notification carrying the entry id', () {
      withRun((run) {
        expect(run.isDone, isFalse, reason: 'nothing written yet');

        stubEntity(audioWith('Late transcript.'));
        run.notify({audioEntryId});

        expect(run.result, 'Late transcript.');
      });
    });

    // Every entity write notifies; only this entry's writes are worth a read.
    test('ignores notifications for other entries', () {
      var reads = 0;
      when(() => journalDb.journalEntityById(audioEntryId)).thenAnswer((
        _,
      ) async {
        reads++;
        return audioWith(null);
      });

      withRun((run) {
        run.notify({'someone-else'});

        expect(run.isDone, isFalse);
        expect(reads, 1, reason: 'only the initial read should have happened');
      });
    });
  });

  group('nothing to offer', () {
    // The audio entry's own creation notification fires before any run; an
    // empty entryText must not be mistaken for a finished transcription.
    test('an empty transcript reads as not-yet', () {
      stubEntity(audioWith('   '));

      withRun((run) {
        run.notify({audioEntryId});

        expect(run.isDone, isFalse);
      });
    });

    test('an entry that is not audio never resolves a transcript', () {
      stubEntity(testTask);

      withRun((run) => expect(run.isDone, isFalse));
    });

    test('an entry that vanished never resolves a transcript', () {
      stubEntity(null);

      withRun((run) => expect(run.isDone, isFalse));
    });
  });

  group('timeout', () {
    test('gives up only once the whole wait has elapsed', () {
      withRun((run) {
        run.settle(checkInTranscriptTimeout - const Duration(seconds: 1));
        expect(run.isDone, isFalse, reason: 'still within the wait');

        run.settle(const Duration(seconds: 2));
        expect(run.isDone, isTrue);
        expect(run.result, isNull);
      });
    });

    test('waits five minutes by default', () {
      expect(checkInTranscriptTimeout, const Duration(minutes: 5));
    });
  });

  group('subscription hygiene', () {
    // The sheet can be opened and dismissed repeatedly; a leaked listener
    // would keep reading the database for every entry write in the session.
    test('detaches its listener once a transcript resolves', () {
      stubEntity(audioWith('done'));

      withRun((run) => expect(run.hasListener, isFalse));
    });

    test('detaches its listener when the wait times out', () {
      withRun((run) {
        expect(run.hasListener, isTrue, reason: 'still waiting');

        run.settle(checkInTranscriptTimeout);

        expect(run.hasListener, isFalse);
      });
    });
  });

  group('provider', () {
    test('builds the service from the journal db and the update bus', () async {
      await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);

      final container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(journalDb),
          profileResolverProvider.overrideWithValue(resolver),
          skillInferenceRunnerProvider.overrideWithValue(runner),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container
            .read(checkInTranscriptionServiceProvider)
            .canTranscribe(),
        isTrue,
      );
    });
  });

  group('system default profile routing', () {
    test(
      'runs only the selected default transcription slot, as a manual request',
      () {
        withRun((run) {
          verify(() => resolver.resolveDefaultProfile()).called(1);
          verifyNoMoreInteractions(resolver);
          final request =
              verify(
                    () => runner.runTranscription(
                      audioEntryId: audioEntryId,
                      automationResult: captureAny(named: 'automationResult'),
                      onError: any(named: 'onError'),
                    ),
                  ).captured.single
                  as AutomationResult;
          expect(request.resolvedProfile, same(defaultProfile));
          expect(request.skill!.id, skillTranscribeContextId);
          expect(
            request.skillAssignment,
            isNull,
            reason: 'A manual check-in must not start automated summary skills',
          );
          expect(
            run.isDone,
            isFalse,
            reason: 'The saved transcript is still pending',
          );
        });
      },
    );

    test('never passes a task id for a person', () {
      withRun((run) {
        final captured = verify(
          () => runner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: captureAny(named: 'linkedTaskId'),
            onError: any(named: 'onError'),
          ),
        ).captured;
        expect(captured.single, isNull);
      });
    });
  });

  group('giving up early', () {
    // Without this the sheet spins for the full five minutes over a
    // configuration problem that was known in milliseconds.
    test('resolves immediately when no model can be resolved', () {
      stubDefault(null);

      withRun((run) {
        expect(run.isDone, isTrue);
        expect(run.result, isNull);
        expect(run.hasListener, isFalse);
      });
    });

    test('resolves immediately when resolving the request throws', () {
      when(() => resolver.resolveDefaultProfile()).thenAnswer(
        (_) async => throw Exception('profile unavailable'),
      );

      withRun((run) {
        expect(run.isDone, isTrue);
        expect(run.result, isNull);
      });
    });

    // The blocker a real HTTP 503 exposed. `runTranscription` reports an
    // inference failure through its status controllers and returns
    // *normally*, so the service's own try/catch never sees it — before the
    // `onError` hook existed the sheet sat on "Transcribing…" for the full
    // five minutes over a provider outage that was known in seconds.
    test('resolves immediately when the run reports a failure', () {
      when(
        () => runner.runTranscription(
          audioEntryId: any(named: 'audioEntryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
          overrideModelId: any(named: 'overrideModelId'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer((invocation) async {
        (invocation.namedArguments[#onError] as void Function(Object)?)?.call(
          Exception('HTTP 503'),
        );
      });

      withRun((run) {
        expect(run.isDone, isTrue, reason: 'must not wait out the timeout');
        expect(run.result, isNull);
        expect(run.hasListener, isFalse);
      });
    });

    // A failure arriving after the transcript already landed must not undo
    // it: `finish` is first-write-wins, and the transcript won that race.
    test('a late failure cannot discard a transcript already resolved', () {
      stubEntity(audioWith('We talked about her job search.'));
      late void Function(Object) reportFailure;
      when(
        () => runner.runTranscription(
          audioEntryId: any(named: 'audioEntryId'),
          automationResult: any(named: 'automationResult'),
          linkedTaskId: any(named: 'linkedTaskId'),
          overrideModelId: any(named: 'overrideModelId'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer((invocation) async {
        reportFailure =
            invocation.namedArguments[#onError] as void Function(Object);
      });

      withRun((run) {
        expect(run.result, 'We talked about her job search.');

        reportFailure(Exception('too late'));
        run.settle();

        expect(run.result, 'We talked about her job search.');
      });
    });
  });

  group('canTranscribe', () {
    late CheckInTranscriptionService service;

    setUp(() {
      service = CheckInTranscriptionService(
        journalDb,
        MockUpdateNotifications(),
        resolver,
        runner,
      );
    });

    test(
      'uses the selected default even without automated skill assignments',
      () async {
        expect(await service.canTranscribe(), isTrue);
        verify(() => resolver.resolveDefaultProfile()).called(1);
        verifyNoMoreInteractions(resolver);
      },
    );

    for (final missing in ['profile', 'model', 'provider']) {
      test(
        'missing default $missing refuses capture and never tries another route',
        () async {
          stubDefault(
            missing == 'profile'
                ? null
                : profile(
                    model: missing != 'model',
                    provider: missing != 'provider',
                  ),
          );
          expect(await service.canTranscribe(), isFalse);
          withRun((run) {
            expect(run.isDone, isTrue);
            expect(run.result, isNull);
            expect(run.hasListener, isFalse);
          });
          verifyZeroInteractions(runner);
          verify(() => resolver.resolveDefaultProfile()).called(2);
          verifyNoMoreInteractions(resolver);
        },
      );
    }
  });

  group('route', () {
    late CheckInTranscriptionService service;

    setUp(() {
      service = CheckInTranscriptionService(
        journalDb,
        MockUpdateNotifications(),
        resolver,
        runner,
      );
    });

    test(
      'names the model and the provider the words would come from',
      () async {
        stubDefault(
          ResolvedProfile(
            thinkingModelId: 'thinking-model',
            thinkingProvider: testInferenceProvider(),
            transcriptionModelId: 'whisper',
            transcriptionProvider: testInferenceProvider(),
            transcriptionModel: testAiModel(),
          ),
        );
        expect(await service.route(), (
          model: 'Test Model',
          provider: 'Gemini',
        ));
      },
    );

    for (final missing in ['profile', 'model', 'provider']) {
      test('is nothing when the default $missing is missing', () async {
        stubDefault(
          missing == 'profile'
              ? null
              : profile(
                  model: missing != 'model',
                  provider: missing != 'provider',
                ),
        );
        expect(await service.route(), isNull);
      });
    }

    test('is nothing when the slot has an id but no resolved model', () async {
      stubDefault(profile());
      expect(await service.route(), isNull);
    });
  });

  group('cancellation', () {
    // A dismissed sheet must stop reading the database on every write for
    // the rest of the timeout.
    test('cancelling resolves null and detaches the listener', () {
      withRun((run) {
        expect(run.isDone, isFalse);

        run.cancel();

        expect(run.isDone, isTrue);
        expect(run.result, isNull);
        expect(run.hasListener, isFalse);
      });
    });

    test('a transcript that lands after cancelling is ignored', () {
      withRun((run) {
        run.cancel();

        stubEntity(audioWith('too late'));
        run.notify({audioEntryId});

        expect(run.result, isNull);
      });
    });
  });
}
