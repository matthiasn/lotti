import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/features/speech/state/recording_receipt_controller.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../relationships/helpers/check_in_speech_fakes.dart';

void main() {
  late FakeAudioRecorderController recorder;
  late MockJournalRepository repository;
  late ProviderContainer container;
  late List<String?> settled;

  final start = DateTime(2026, 11, 24, 9);
  const origin = RecordingOrigin(route: '/tasks/task-1', subjectId: 'task-1');

  setUp(() {
    recorder = FakeAudioRecorderController();
    repository = MockJournalRepository();
    settled = [];
    when(
      () => repository.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
    // Built before any fake zone, so its first read happens in the test.
    container = ProviderContainer(
      overrides: [
        audioRecorderControllerProvider.overrideWith(() => recorder),
        journalRepositoryProvider.overrideWithValue(repository),
      ],
    )..read(audioRecorderControllerProvider);
  });
  tearDown(() => container.dispose());

  RecordingReceiptController receipts() =>
      container.read(recordingReceiptControllerProvider.notifier);
  RecordingReceipt? shown() =>
      container.read(recordingReceiptControllerProvider);

  void show(String id, {String? subjectTitle = 'Fix the airlock'}) =>
      receipts().show(
        entryId: id,
        duration: const Duration(seconds: 42),
        subjectId: 'task-1',
        subjectTitle: subjectTitle,
        origin: origin,
        onSettled: settled.add,
      );

  /// Runs [body] in fake time starting at [start].
  void inFakeTime(void Function(FakeAsync async) body) => fakeAsync(
    (async) => withClock(async.getClock(start), () => body(async)),
    initialTime: start,
  );

  test('starts with no receipt', () {
    expect(shown(), isNull);
  });

  test('show puts up what was saved, due to commit after the window', () {
    inFakeTime((async) {
      show('audio-1');
      expect(
        shown(),
        RecordingReceipt(
          entryId: 'audio-1',
          duration: const Duration(seconds: 42),
          deadline: start.add(recordingReceiptWindow),
          subjectId: 'task-1',
          subjectTitle: 'Fix the airlock',
          origin: origin,
        ),
      );
      expect(settled, isEmpty);
    });
  });

  group('the window', () {
    test('holds the receipt until the last moment, and commits nothing', () {
      inFakeTime((async) {
        show('audio-1');
        async.elapse(
          recordingReceiptWindow - const Duration(milliseconds: 1),
        );
        expect(shown(), isNotNull);
        expect(settled, isEmpty);
        expect(recorder.committedAutomation, isEmpty);
      });
    });

    test('running out commits the take: its prompts start and its caller '
        'hears the id', () {
      inFakeTime((async) {
        show('audio-1');
        async.elapse(recordingReceiptWindow);
        expect(shown(), isNull);
        expect(settled, ['audio-1']);
        expect(recorder.committedAutomation, ['audio-1']);
      });
    });
  });

  group('commit (Open, or a new take)', () {
    test('commits at once, and the timer then has nothing to commit', () {
      inFakeTime((async) {
        show('audio-1');
        receipts().commit();
        expect(shown(), isNull);
        expect(settled, ['audio-1']);
        async.elapse(recordingReceiptWindow * 2);
        expect(settled, ['audio-1']);
        expect(recorder.committedAutomation, ['audio-1']);
      });
    });

    test('with no receipt on screen does nothing', () {
      receipts().commit();
      expect(settled, isEmpty);
      expect(recorder.committedAutomation, isEmpty);
    });

    test('a second receipt commits the first before it shows', () {
      inFakeTime((async) {
        show('audio-1');
        show('audio-2');
        expect(settled, ['audio-1']);
        expect(shown()?.entryId, 'audio-2');
        async.elapse(recordingReceiptWindow);
        expect(settled, ['audio-1', 'audio-2']);
      });
    });
  });

  group('undo', () {
    test('deletes the entry, owes it nothing, and tells the caller it is '
        'gone', () {
      inFakeTime((async) {
        show('audio-1');
        receipts().undo();
        async.flushMicrotasks();
        verify(() => repository.deleteJournalEntity('audio-1')).called(1);
        expect(shown(), isNull);
        expect(recorder.droppedAutomation, ['audio-1']);
        expect(recorder.committedAutomation, isEmpty);
        expect(settled, [null]);
      });
    });

    test('the timer firing behind an Undo settles nothing twice', () {
      inFakeTime((async) {
        show('audio-1');
        receipts().undo();
        async
          ..flushMicrotasks()
          ..elapse(recordingReceiptWindow * 2);
        expect(settled, [null]);
        expect(recorder.committedAutomation, isEmpty);
      });
    });

    test('a deletion that did not land keeps the take: it is committed after '
        'all', () {
      when(
        () => repository.deleteJournalEntity('audio-1'),
      ).thenAnswer((_) async => false);
      inFakeTime((async) {
        show('audio-1');
        receipts().undo();
        async.flushMicrotasks();
        expect(recorder.droppedAutomation, isEmpty);
        expect(recorder.committedAutomation, ['audio-1']);
        expect(settled, ['audio-1']);
      });
    });

    test('with no receipt on screen does nothing', () async {
      await receipts().undo();
      verifyNever(() => repository.deleteJournalEntity(any()));
      expect(settled, isEmpty);
    });
  });

  test('a receipt shown without a listener still commits quietly', () {
    inFakeTime((async) {
      receipts().show(entryId: 'audio-9', duration: Duration.zero);
      async.elapse(recordingReceiptWindow);
      expect(shown(), isNull);
      expect(recorder.committedAutomation, ['audio-9']);
    });
  });

  test('disposing the container cancels the pending commit', () {
    inFakeTime((async) {
      show('audio-1');
      container.dispose();
      async.elapse(recordingReceiptWindow);
      expect(settled, isEmpty);
      // tearDown disposes again; a second dispose is a no-op.
    });
  });

  test('receipts are equal by value', () {
    final a = RecordingReceipt(
      entryId: 'audio-1',
      duration: const Duration(seconds: 3),
      deadline: start,
      subjectId: 'task-1',
      subjectTitle: 'Fix the airlock',
      origin: origin,
    );
    final b = RecordingReceipt(
      entryId: 'audio-1',
      duration: const Duration(seconds: 3),
      deadline: start,
      subjectId: 'task-1',
      subjectTitle: 'Fix the airlock',
      origin: origin,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(
        RecordingReceipt(
          entryId: 'audio-2',
          duration: const Duration(seconds: 3),
          deadline: start,
        ),
      ),
    );
  });
}
