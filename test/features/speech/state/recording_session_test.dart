import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/features/speech/state/recording_return.dart';
import 'package:lotti/features/speech/state/recording_session.dart';
import 'package:lotti/features/speech/state/recording_start_guard.dart';
import 'package:lotti/features/speech/state/recording_tray_controller.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../relationships/helpers/check_in_speech_fakes.dart';

/// A session wired to a scriptable recorder, a mocked navigation service and
/// journal, and the real receipt, tray and scroll state.
class _Bench {
  _Bench({FakeAudioRecorderController? recorder, bool withNav = true})
    : recorder = recorder ?? FakeAudioRecorderController() {
    when(() => nav.activeRoute).thenReturn('/tasks/${testTask.meta.id}');
    when(() => nav.canBeamTo(any())).thenReturn(true);
    when(
      () => db.journalEntityById(testTask.meta.id),
    ).thenAnswer((_) async => testTask);
    when(
      () => repository.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
    container = ProviderContainer(
      overrides: [
        audioRecorderControllerProvider.overrideWith(() => this.recorder),
        journalRepositoryProvider.overrideWithValue(repository),
        journalDbProvider.overrideWithValue(db),
        if (withNav) navServiceProvider.overrideWithValue(nav),
      ],
    );
  }

  final FakeAudioRecorderController recorder;
  final nav = MockNavService();
  final db = MockJournalDb();
  final repository = MockJournalRepository();
  late final ProviderContainer container;

  RecordingSession get session => container.read(recordingSessionProvider);
  RecordingTrayState get tray =>
      container.read(recordingTrayControllerProvider);
  RecordingReceipt? get receipt =>
      container.read(recordingReceiptControllerProvider);
  RecordingReceiptController get receipts =>
      container.read(recordingReceiptControllerProvider.notifier);
  RecordingOriginScroll get scroll =>
      container.read(recordingOriginScrollProvider);

  /// Starts a take for the task, without waiting for it to be committed.
  Future<String?> startTaskTake({
    bool transcriptionHandledByCaller = false,
  }) {
    final done = session.start(
      linkedId: testTask.meta.id,
      categoryId: 'category-7',
      transcriptionHandledByCaller: transcriptionHandledByCaller,
    );
    return done;
  }
}

/// A recorder whose take its caller transcribes itself.
class _CallerTranscribes extends FakeAudioRecorderController {
  _CallerTranscribes({super.runningFor});

  @override
  bool get transcriptionHandledByCaller => true;
}

void main() {
  late _Bench bench;

  setUp(() => bench = _Bench());
  tearDown(() => bench.container.dispose());

  group('start', () {
    test('starts the take at once for its subject and category, with the '
        'route on screen and its scroll offset as the origin', () async {
      bench.scroll.report('/tasks/${testTask.meta.id}', 320);
      bench.startTaskTake().ignore();
      await pumpEventQueue();

      expect(bench.recorder.recordCalls, [
        (linkedId: testTask.meta.id, handledByCaller: false),
      ]);
      expect(bench.recorder.categoryIds, ['category-7']);
      expect(bench.recorder.recordOrigins, [
        RecordingOrigin(
          route: '/tasks/${testTask.meta.id}',
          subjectId: testTask.meta.id,
          scrollOffset: 320,
        ),
      ]);
      expect(bench.tray.open, isFalse);
    });

    test('an origin the caller names wins over the route on screen', () async {
      const origin = RecordingOrigin(route: '/calendar');
      bench.session.start(origin: origin).ignore();
      await pumpEventQueue();

      expect(bench.recorder.recordOrigins, [origin]);
    });

    test('with no navigation wired up the take has no origin', () async {
      bench.container.dispose();
      bench = _Bench(withNav: false);
      bench.startTaskTake().ignore();
      await pumpEventQueue();

      expect(bench.recorder.recordOrigins, [null]);
    });

    test(
      'passes the caller transcribing the take on to the recorder',
      () async {
        bench.startTaskTake(transcriptionHandledByCaller: true).ignore();
        await pumpEventQueue();

        expect(bench.recorder.recordCalls.single.handledByCaller, isTrue);
      },
    );

    test('commits a receipt still on screen before the new take', () async {
      final settled = <String?>[];
      bench.receipts.show(
        entryId: 'old-take',
        duration: Duration.zero,
        onSettled: settled.add,
      );
      bench.startTaskTake().ignore();
      await pumpEventQueue();

      expect(settled, ['old-take']);
      expect(bench.receipt, isNull);
    });

    test("another subject's take is left alone: the tray opens on Stop that "
        'recording, and the start answers null', () async {
      bench.container.dispose();
      bench = _Bench(
        recorder: FakeAudioRecorderController(runningFor: 'other-task'),
      );

      expect(await bench.startTaskTake(), isNull);
      expect(bench.recorder.recordCalls, isEmpty);
      expect(bench.tray, (
        open: true,
        failure: InlineRecordingFailure.recorderBusy,
      ));
    });

    test("this subject's running take is not started again: the tray opens "
        'over it, and the start answers with that take', () async {
      final first = bench.startTaskTake();
      await pumpEventQueue();
      final again = bench.startTaskTake();
      await pumpEventQueue();

      expect(bench.recorder.recordCalls, hasLength(1));
      expect(bench.tray, (open: true, failure: null));

      await bench.session.stop();
      bench.receipts.commit();
      expect(await first, 'audio-1');
      expect(await again, 'audio-1');
    });

    test('attaching to a take started elsewhere answers null', () async {
      bench.container.dispose();
      bench = _Bench(
        recorder: FakeAudioRecorderController(runningFor: testTask.meta.id),
      );

      expect(await bench.startTaskTake(), isNull);
      expect(bench.tray.open, isTrue);
    });

    for (final (refusal, failure) in [
      (
        AudioRecordingFailure.permissionDenied,
        InlineRecordingFailure.microphoneDenied,
      ),
      (
        AudioRecordingFailure.startFailed,
        InlineRecordingFailure.startFailed,
      ),
    ]) {
      test('a ${refusal.name} start opens the tray on ${failure.name}, and '
          'answers null', () async {
        bench.recorder.recordFailure = refusal;

        expect(await bench.startTaskTake(), isNull);
        expect(bench.tray, (open: true, failure: failure));
      });
    }
  });

  group('stop', () {
    test('with nothing recording does nothing', () async {
      await bench.session.stop();

      expect(bench.recorder.stopCalls, 0);
      expect(bench.receipt, isNull);
    });

    test(
      'saves the take, defers its prompts, folds the tray and puts up a '
      "receipt naming the subject, the take's length and its origin",
      () async {
        bench.startTaskTake().ignore();
        await pumpEventQueue();
        bench.recorder.tick(progress: const Duration(seconds: 42));
        bench.container.read(recordingTrayControllerProvider.notifier).open();

        await bench.session.stop();

        expect(bench.recorder.stopDeferrals, [true]);
        expect(bench.tray.open, isFalse);
        final receipt = bench.receipt!;
        expect(receipt.entryId, 'audio-1');
        expect(receipt.subjectId, testTask.meta.id);
        expect(receipt.subjectTitle, testTask.data.title);
        expect(receipt.duration, const Duration(seconds: 42));
        expect(receipt.origin?.route, '/tasks/${testTask.meta.id}');
      },
    );

    test('the take is answered at commit, with the id', () async {
      String? answer = 'pending';
      bench.startTaskTake().then((id) => answer = id).ignore();
      await pumpEventQueue();
      await bench.session.stop();
      await pumpEventQueue();
      expect(answer, 'pending');

      bench.receipts.commit();
      await pumpEventQueue();
      expect(answer, 'audio-1');
    });

    test('the take is answered null after Undo', () async {
      final done = bench.startTaskTake();
      await pumpEventQueue();
      await bench.session.stop();
      await bench.receipts.undo();

      expect(await done, isNull);
    });

    test(
      'a subject deleted mid-take leaves the receipt with no title',
      () async {
        when(
          () => bench.db.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => null);
        bench.startTaskTake().ignore();
        await pumpEventQueue();
        await bench.session.stop();

        expect(bench.receipt?.subjectTitle, isNull);
      },
    );

    test('a take that could not be saved answers null and opens the tray on '
        'not saved', () async {
      bench.recorder.stopResult = null;
      final done = bench.startTaskTake();
      await pumpEventQueue();
      await bench.session.stop();

      expect(await done, isNull);
      expect(bench.receipt, isNull);
      expect(bench.tray, (
        open: true,
        failure: InlineRecordingFailure.notSaved,
      ));
    });

    test('a take started elsewhere still gets its receipt', () async {
      bench.container.dispose();
      bench = _Bench(
        recorder: FakeAudioRecorderController(runningFor: testTask.meta.id),
      );
      await bench.session.stop();

      expect(bench.receipt?.entryId, 'audio-1');
      bench.receipts.commit();
      expect(bench.recorder.committedAutomation, ['audio-1']);
    });
  });

  group('a voice note', () {
    Future<String?> startVoiceNote({bool openCreatedEntry = true}) async {
      final done = bench.session.start(openCreatedEntry: openCreatedEntry);
      await pumpEventQueue();
      await bench.session.stop();
      return done;
    }

    test('opens its entry when committed', () async {
      final done = startVoiceNote();
      await pumpEventQueue();
      expect(bench.receipt?.subjectTitle, isNull);
      verifyNever(() => bench.nav.beamToNamed(any()));

      bench.receipts.commit();
      expect(await done, 'audio-1');
      verify(() => bench.nav.beamToNamed('/journal/audio-1')).called(1);
    });

    test('stays where it is when its caller links it itself', () async {
      final done = startVoiceNote(openCreatedEntry: false);
      await pumpEventQueue();
      bench.receipts.commit();

      expect(await done, 'audio-1');
      verifyNever(() => bench.nav.beamToNamed(any()));
    });

    test('opens nothing when undone', () async {
      final done = startVoiceNote();
      await pumpEventQueue();
      await bench.receipts.undo();

      expect(await done, isNull);
      verifyNever(() => bench.nav.beamToNamed(any()));
    });
  });

  group('the receipt says a transcript is coming', () {
    Future<bool?> transcribingAfterStop() async {
      await pumpEventQueue();
      await bench.session.stop();
      final transcribing = bench.receipt?.transcribing;
      bench.receipts.commit();
      return transcribing;
    }

    test('for a subject, with Transcribe left on', () async {
      bench.startTaskTake().ignore();
      expect(await transcribingAfterStop(), isTrue);
    });

    test('not with Transcribe switched off', () async {
      bench.startTaskTake().ignore();
      await pumpEventQueue();
      bench.recorder.setEnableSpeechRecognition(enable: false);
      expect(await transcribingAfterStop(), isFalse);
    });

    test('not for a take its caller transcribes', () async {
      bench.container.dispose();
      bench = _Bench(
        recorder: _CallerTranscribes(runningFor: testTask.meta.id),
      );
      expect(await transcribingAfterStop(), isFalse);
    });

    test('not for a voice note', () async {
      bench.session.start().ignore();
      expect(await transcribingAfterStop(), isFalse);
    });

    test('not for a subject deleted mid-take', () async {
      when(
        () => bench.db.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => null);
      bench.startTaskTake().ignore();
      expect(await transcribingAfterStop(), isFalse);
    });
  });

  group('openReceipt', () {
    test('with no receipt on screen does nothing', () async {
      await bench.session.openReceipt();
      verifyNever(() => bench.nav.beamToNamed(any()));
    });

    test(
      "commits a subject's take and goes back to where it started",
      () async {
        final done = bench.startTaskTake();
        await pumpEventQueue();
        await bench.session.stop();

        await bench.session.openReceipt();

        expect(await done, 'audio-1');
        expect(bench.receipt, isNull);
        verify(
          () => bench.nav.beamToNamed('/tasks/${testTask.meta.id}'),
        ).called(1);
      },
    );

    test("opens a voice note's entry, even for a caller that keeps it "
        'closed otherwise', () async {
      bench.session.start(openCreatedEntry: false).ignore();
      await pumpEventQueue();
      await bench.session.stop();

      await bench.session.openReceipt();

      verify(() => bench.nav.beamToNamed('/journal/audio-1')).called(1);
    });

    test(
      'a later voice note committed by its timer stays closed again',
      () async {
        bench.session.start(openCreatedEntry: false).ignore();
        await pumpEventQueue();
        await bench.session.stop();
        await bench.session.openReceipt();
        clearInteractions(bench.nav);

        bench.session.start(openCreatedEntry: false).ignore();
        await pumpEventQueue();
        await bench.session.stop();
        bench.receipts.commit();

        verifyNever(() => bench.nav.beamToNamed(any()));
      },
    );
  });

  group('discard', () {
    test('throws the take away, folds the tray and answers null', () async {
      final done = bench.startTaskTake();
      await pumpEventQueue();
      bench.container.read(recordingTrayControllerProvider.notifier).open();

      await bench.session.discard();

      expect(await done, isNull);
      expect(bench.recorder.cancelCalls, 1);
      expect(bench.tray.open, isFalse);
      expect(bench.receipt, isNull);
    });

    test('a take started elsewhere is still thrown away', () async {
      bench.container.dispose();
      bench = _Bench(
        recorder: FakeAudioRecorderController(runningFor: testTask.meta.id),
      );
      await bench.session.discard();

      expect(bench.recorder.cancelCalls, 1);
    });
  });

  group('returnToOrigin', () {
    final origin = RecordingOrigin(
      route: '/tasks/${testTask.meta.id}',
      subjectId: testTask.meta.id,
      scrollOffset: 320,
    );

    test('goes to the origin route, owes its page the scroll offset, and '
        'marks the arrival at the subject', () async {
      expect(await bench.session.returnToOrigin(origin), isTrue);

      verify(
        () => bench.nav.beamToNamed('/tasks/${testTask.meta.id}'),
      ).called(1);
      expect(bench.scroll.takeRestore('/tasks/${testTask.meta.id}'), 320);
      expect(
        bench.container.read(recordingArrivalProvider)?.subjectId,
        testTask.meta.id,
      );
    });

    test('owes no scroll where the page reported none', () async {
      await bench.session.returnToOrigin(
        origin.copyWith(scrollOffset: null),
      );

      expect(bench.scroll.takeRestore('/tasks/${testTask.meta.id}'), isNull);
    });

    test("falls back to the subject's own page when the route no longer "
        'resolves', () async {
      const goneRoute = '/calendar/time';
      when(() => bench.nav.canBeamTo(goneRoute)).thenReturn(false);

      expect(
        await bench.session.returnToOrigin(origin.copyWith(route: goneRoute)),
        isTrue,
      );
      verify(
        () => bench.nav.beamToNamed('/tasks/${testTask.meta.id}'),
      ).called(1);
      expect(bench.scroll.takeRestore(goneRoute), isNull);
    });

    test('goes nowhere when neither the route nor the subject page '
        'resolves', () async {
      when(() => bench.nav.canBeamTo(any())).thenReturn(false);

      expect(await bench.session.returnToOrigin(origin), isFalse);
      verifyNever(() => bench.nav.beamToNamed(any()));
      expect(bench.container.read(recordingArrivalProvider), isNull);
    });

    test('goes nowhere once the subject is deleted', () async {
      when(
        () => bench.db.journalEntityById(testTask.meta.id),
      ).thenAnswer((_) async => null);

      expect(await bench.session.returnToOrigin(origin), isFalse);
      verifyNever(() => bench.nav.beamToNamed(any()));
    });

    test(
      'a take with no subject goes back to its route, with no arrival',
      () async {
        expect(
          await bench.session.returnToOrigin(
            const RecordingOrigin(route: '/calendar'),
          ),
          isTrue,
        );
        verify(() => bench.nav.beamToNamed('/calendar')).called(1);
        expect(bench.container.read(recordingArrivalProvider), isNull);
      },
    );

    test('a take with no subject whose route is gone goes nowhere', () async {
      when(() => bench.nav.canBeamTo('/calendar')).thenReturn(false);

      expect(
        await bench.session.returnToOrigin(
          const RecordingOrigin(route: '/calendar'),
        ),
        isFalse,
      );
    });
  });
}
