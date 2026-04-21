import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class MockEvent extends Mock implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  Event makeEvent({
    required String eventId,
    required String relativePath,
    String mime = 'image/jpeg',
  }) {
    final e = MockEvent();
    when(() => e.eventId).thenReturn(eventId);
    when(() => e.attachmentMimetype).thenReturn(mime);
    when(() => e.content).thenReturn({'relativePath': relativePath});
    return e;
  }

  test(
    'record is idempotent per eventId — repeat observations are no-ops '
    'and emit no log',
    () {
      final logging = MockLoggingService();
      final index = AttachmentIndex(logging: logging);
      final e = makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');

      expect(index.record(e), isTrue);
      expect(index.record(e), isFalse);
      expect(index.record(e), isFalse);

      verify(
        () => logging.captureEvent(
          any<String>(that: contains('attachmentIndex.record')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachmentIndex.record',
        ),
      ).called(1);
    },
  );

  test(
    'verboseLogging: false suppresses per-event record/find lines without '
    'changing behaviour',
    () {
      final logging = MockLoggingService();
      final index = AttachmentIndex(logging: logging, verboseLogging: false);
      final e = makeEvent(eventId: 'ev1', relativePath: 'images/a.jpg');

      expect(index.record(e), isTrue);
      expect(index.record(e), isFalse);
      expect(index.find('images/a.jpg'), isNotNull);
      expect(index.find('images/missing.jpg'), isNull);

      verifyNever(
        () => logging.captureEvent(
          any<String>(that: contains('attachmentIndex.')),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      );
    },
  );

  test(
    'record does not thrash when multiple events share one relativePath — '
    'each eventId logs exactly once regardless of interleaving',
    () {
      final logging = MockLoggingService();
      final index = AttachmentIndex(logging: logging);
      final a = makeEvent(eventId: 'A', relativePath: 'audio/x.m4a');
      final b = makeEvent(eventId: 'B', relativePath: 'audio/x.m4a');

      // Interleave observations like catch-up + live-scan would.
      expect(index.record(a), isTrue);
      expect(index.record(b), isTrue);
      expect(index.record(a), isFalse);
      expect(index.record(b), isFalse);
      expect(index.record(a), isFalse);
      expect(index.record(b), isFalse);

      verify(
        () => logging.captureEvent(
          any<String>(that: contains('attachmentIndex.record')),
          domain: any<String>(named: 'domain'),
          subDomain: 'attachmentIndex.record',
        ),
      ).called(2);
    },
  );

  test('record and find works with and without leading slash', () {
    final logging = MockLoggingService();
    final index = AttachmentIndex(logging: logging);
    final e = MockEvent();
    when(() => e.attachmentMimetype).thenReturn('image/jpeg');
    when(() => e.content).thenReturn({'relativePath': 'images/a.jpg'});
    when(() => e.eventId).thenReturn('ev1');

    index.record(e);

    // Hit with slash
    final hit1 = index.find('/images/a.jpg');
    expect(hit1, isNotNull);
    // Hit without slash
    final hit2 = index.find('images/a.jpg');
    expect(hit2, isNotNull);

    // Miss logs a miss
    final miss = index.find('/images/missing.jpg');
    expect(miss, isNull);
    verify(
      () => logging.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: 'attachmentIndex.find',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test(
    'pathRecorded stream emits the canonical (leading-slash) path on '
    'each first-time record so subscribers — notably the queue '
    'coordinator — can react the moment an attachment JSON lands',
    () async {
      final logging = MockLoggingService();
      final index = AttachmentIndex(logging: logging);
      final paths = <String>[];
      final sub = index.pathRecorded.listen(paths.add);

      final e1 = MockEvent();
      when(() => e1.attachmentMimetype).thenReturn('image/jpeg');
      when(() => e1.content).thenReturn({'relativePath': 'images/a.jpg'});
      when(() => e1.eventId).thenReturn('ev1');
      index.record(e1);

      // Even when the caller passes a path without a leading slash,
      // the stream should emit the canonical `/images/a.jpg` form so
      // subscribers have a single shape to match against.
      await Future<void>.delayed(Duration.zero);
      expect(paths, ['/images/a.jpg']);

      // Idempotency guard: re-observing the same event does not
      // re-emit on the stream. Different event id, same path, only
      // updates the `_byPath` slot — still a mutation, still a
      // signal.
      index.record(e1);
      final e2 = MockEvent();
      when(() => e2.attachmentMimetype).thenReturn('image/jpeg');
      when(() => e2.content).thenReturn({'relativePath': 'images/a.jpg'});
      when(() => e2.eventId).thenReturn('ev2');
      index.record(e2);

      await Future<void>.delayed(Duration.zero);
      expect(paths, ['/images/a.jpg', '/images/a.jpg']);

      await sub.cancel();
      await index.dispose();
    },
  );

  test(
    'dispose closes the pathRecorded stream so app shutdown / test '
    'teardown does not leak the broadcast controller',
    () async {
      final index = AttachmentIndex(logging: MockLoggingService());
      var done = false;
      final sub = index.pathRecorded.listen(
        (_) {},
        onDone: () => done = true,
      );
      await index.dispose();
      await sub.cancel();
      expect(done, isTrue);
    },
  );
}
