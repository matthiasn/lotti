import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_missing_notifier.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(LogDomain.sync);
    registerFallbackValue(StackTrace.empty);
  });

  late MockDomainLogger logging;
  late SyncSequenceTracer tracer;
  late SyncSequenceMissingNotifier notifier;

  setUp(() {
    logging = MockDomainLogger();
    when(
      () => logging.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    tracer = SyncSequenceTracer(loggingService: logging);
    notifier = SyncSequenceMissingNotifier(tracer: tracer);
  });

  test('flag emits immediately when not deferred', () {
    var calls = 0;
    notifier
      ..onMissingEntriesDetected = (() => calls++)
      ..flagMissingEntriesDetected();

    expect(calls, 1);
    expect(notifier.isDeferred, isFalse);
  });

  test('flag is a no-op when no callback is wired', () {
    expect(notifier.flagMissingEntriesDetected, returnsNormally);
  });

  test(
    'deferred flags coalesce into a single emission on scope exit',
    () async {
      var calls = 0;
      notifier.onMissingEntriesDetected = () => calls++;

      await notifier.runWithDeferredMissingEntries(() async {
        expect(notifier.isDeferred, isTrue);
        notifier
          ..flagMissingEntriesDetected()
          ..flagMissingEntriesDetected();
        // Still deferred — nothing emitted yet.
        expect(calls, 0);
      });

      expect(calls, 1);
      expect(notifier.isDeferred, isFalse);
    },
  );

  test('nested scopes only emit when the outermost unwinds', () async {
    var calls = 0;
    notifier.onMissingEntriesDetected = () => calls++;

    await notifier.runWithDeferredMissingEntries(() async {
      await notifier.runWithDeferredMissingEntries(() async {
        notifier.flagMissingEntriesDetected();
      });
      // Inner scope closed but outer still open.
      expect(calls, 0);
      expect(notifier.isDeferred, isTrue);
    });

    expect(calls, 1);
  });

  test('no flag inside a deferred scope emits nothing on exit', () async {
    var calls = 0;
    notifier.onMissingEntriesDetected = () => calls++;

    await notifier.runWithDeferredMissingEntries(() async {});

    expect(calls, 0);
  });

  test('deferred depth unwinds even when the action throws', () async {
    var calls = 0;
    notifier.onMissingEntriesDetected = () => calls++;

    await expectLater(
      notifier.runWithDeferredMissingEntries(() async {
        notifier.flagMissingEntriesDetected();
        throw StateError('boom');
      }),
      throwsStateError,
    );

    // Pending flag still flushed in the finally block.
    expect(calls, 1);
    expect(notifier.isDeferred, isFalse);
  });

  test('a throwing listener is logged and swallowed', () {
    final thrown = Exception('listener failed');
    notifier.onMissingEntriesDetected = () => throw thrown;

    expect(notifier.emitMissingEntriesDetected, returnsNormally);
    verify(
      () => logging.error(
        LogDomain.sync,
        thrown,
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: 'missingEntriesDetected',
      ),
    ).called(1);
  });
}
