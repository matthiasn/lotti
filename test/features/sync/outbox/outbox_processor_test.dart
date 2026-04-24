import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockMessageSender extends Mock implements OutboxMessageSender {}

OutboxItem _item({
  int id = 1,
  String subject = 'host:1',
  int retries = 0,
  String messageId = 'cfg',
  DateTime? updatedAt,
}) {
  return OutboxItem(
    id: id,
    message: jsonEncode(SyncMessage.aiConfigDelete(id: messageId).toJson()),
    subject: subject,
    status: OutboxStatus.pending.index,
    retries: retries,
    createdAt: DateTime(2024),
    updatedAt: updatedAt ?? DateTime(2024),
    priority: OutboxPriority.low.index,
  );
}

void _stubSilentLogging(MockLoggingService log) {
  when(
    () => log.captureEvent(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
    ),
  ).thenAnswer((_) {});
  when(
    () => log.captureException(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
    ),
  ).thenAnswer((_) async {});
}

List<String> _captureEvents(MockLoggingService log) {
  final events = <String>[];
  when(
    () => log.captureEvent(
      captureAny<Object>(),
      domain: any(named: 'domain'),
      subDomain: any(named: 'subDomain'),
    ),
  ).thenAnswer((inv) {
    events.add(inv.positionalArguments.first.toString());
  });
  when(
    () => log.captureException(
      any<Object>(),
      domain: any(named: 'domain'),
      subDomain: any(named: 'subDomain'),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
    ),
  ).thenAnswer((_) async {});
  return events;
}

void _stubClaimSequence(
  MockOutboxRepository repo,
  List<OutboxItem?> items,
) {
  var call = 0;
  when(
    () => repo.claim(leaseDuration: any(named: 'leaseDuration')),
  ).thenAnswer((_) async {
    if (call >= items.length) return null;
    return items[call++];
  });
}

void _stubHasMorePending(MockOutboxRepository repo, {bool hasMore = false}) {
  when(() => repo.hasMorePending()).thenAnswer((_) async => hasMore);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_item());
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'x'));
    registerFallbackValue(StackTrace.empty);
  });

  test('send timeout triggers retry and schedules backoff', () async {
    fakeAsync((async) {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      final pending = _item();
      _stubClaimSequence(repo, [pending]);
      _stubHasMorePending(repo);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      // Sender never completes; processQueue relies on the timeout
      when(
        () => sender.send(any()),
      ).thenAnswer((_) => Completer<bool>().future);
      _stubSilentLogging(log);

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
        retryDelayOverride: const Duration(milliseconds: 200),
        sendTimeoutOverride: const Duration(milliseconds: 50),
      );

      OutboxProcessingResult? result;
      unawaited(proc.processQueue().then((r) => result = r));
      // Advance past the timeout (50ms) and the retry delay observation window
      async
        ..elapse(const Duration(seconds: 1))
        ..flushMicrotasks();
      expect(result, isNotNull);
      expect(result!.shouldSchedule, isTrue);
      expect(result!.nextDelay?.inMilliseconds, 200);
      verify(() => repo.markRetry(any())).called(1);
    });
  });

  test('exits early when claim returns null (empty queue)', () async {
    final repo = MockOutboxRepository();
    final sender = MockMessageSender();
    final log = MockLoggingService();

    when(
      () => repo.claim(leaseDuration: any(named: 'leaseDuration')),
    ).thenAnswer((_) async => null);
    _stubSilentLogging(log);

    final proc = OutboxProcessor(
      repository: repo,
      messageSender: sender,
      loggingService: log,
    );

    final result = await proc.processQueue();

    expect(result.shouldSchedule, isFalse);
    verifyNever(() => sender.send(any()));
    verifyNever(() => repo.markSent(any()));
    verifyNever(() => repo.markRetry(any()));
  });

  test('schedules next pass when more items remain after send', () async {
    final repo = MockOutboxRepository();
    final sender = MockMessageSender();
    final log = MockLoggingService();

    _stubClaimSequence(repo, [_item()]);
    _stubHasMorePending(repo, hasMore: true);
    when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
    when(() => sender.send(any())).thenAnswer((_) async => true);
    _stubSilentLogging(log);

    final proc = OutboxProcessor(
      repository: repo,
      messageSender: sender,
      loggingService: log,
    );

    final result = await proc.processQueue();

    expect(result.shouldSchedule, isTrue);
    expect(result.nextDelay, Duration.zero);
    verify(() => repo.markSent(any())).called(1);
  });

  test('schedules no next pass when queue is drained after send', () async {
    final repo = MockOutboxRepository();
    final sender = MockMessageSender();
    final log = MockLoggingService();

    _stubClaimSequence(repo, [_item()]);
    _stubHasMorePending(repo);
    when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
    when(() => sender.send(any())).thenAnswer((_) async => true);
    _stubSilentLogging(log);

    final proc = OutboxProcessor(
      repository: repo,
      messageSender: sender,
      loggingService: log,
    );

    final result = await proc.processQueue();

    expect(result.shouldSchedule, isFalse);
    verify(() => repo.markSent(any())).called(1);
  });

  group('retry cap', () {
    test('retry cap on send failure advances queue (delay=0) and logs', () {
      fakeAsync((async) {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        // maxRetriesOverride=3 → retries=2 + 1 hits cap
        final pending = _item(subject: 'host:cap', retries: 2);
        _stubClaimSequence(repo, [pending]);
        _stubHasMorePending(repo);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);
        final events = _captureEvents(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          maxRetriesOverride: 3,
        );

        OutboxProcessingResult? result;
        unawaited(proc.processQueue().then((r) => result = r));
        async.flushMicrotasks();
        expect(result, isNotNull);
        expect(result!.shouldSchedule, isTrue);
        expect(result!.nextDelay, Duration.zero);
        verify(() => repo.markRetry(any())).called(1);
        verify(
          () => log.captureEvent(
            startsWith('retryCapReached subject=host:cap attempts=3'),
            domain: 'OUTBOX',
            subDomain: 'retry.cap',
          ),
        ).called(1);
        expect(
          events.any(
            (e) =>
                e.contains('retryCapReached subject=host:cap attempts=3') &&
                e.contains('status=error'),
          ),
          isTrue,
        );
      });
    });

    test('retry cap on exception advances queue and logs', () {
      fakeAsync((async) {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final pending = _item(id: 2, subject: 'host:cap-ex', retries: 2);
        _stubClaimSequence(repo, [pending]);
        _stubHasMorePending(repo);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenThrow(Exception('boom'));
        final events = _captureEvents(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          maxRetriesOverride: 3,
        );

        OutboxProcessingResult? result;
        unawaited(proc.processQueue().then((r) => result = r));
        async.flushMicrotasks();
        expect(result, isNotNull);
        expect(result!.shouldSchedule, isTrue);
        expect(result!.nextDelay, Duration.zero);
        verify(() => repo.markRetry(any())).called(1);
        verify(
          () => log.captureEvent(
            startsWith('retryCapReached subject=host:cap-ex attempts=3'),
            domain: 'OUTBOX',
            subDomain: 'retry.cap',
          ),
        ).called(1);
        expect(
          events.any(
            (e) =>
                e.contains('retryCapReached subject=host:cap-ex attempts=3') &&
                e.contains('status=error'),
          ),
          isTrue,
        );
      });
    });

    test('queue continues processing after capped item', () async {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      final a = _item(id: 11, subject: 'A', retries: 2, messageId: 'A');
      final b = _item(id: 12, subject: 'B', messageId: 'B');

      _stubClaimSequence(repo, [a, b]);
      _stubHasMorePending(repo);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
      var sendCalls = 0;
      when(() => sender.send(any())).thenAnswer((_) async {
        sendCalls++;
        // First call (A) fails at cap; second call (B) succeeds
        return sendCalls == 2;
      });
      _stubSilentLogging(log);

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
        maxRetriesOverride: 3,
      );

      final r1 = await proc.processQueue();
      expect(
        r1.nextDelay,
        Duration.zero,
      ); // cap reached → immediate continuation
      final r2 = await proc.processQueue();
      expect(r2.shouldSchedule, isFalse); // only one item (B) and it succeeded
      verify(() => repo.markSent(any())).called(1);
    });
  });

  group('timeout and diagnostics', () {
    test('timeout on slow send logs timedOut=true', () {
      fakeAsync((async) {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        _stubClaimSequence(repo, [_item(id: 3, subject: 'host:slow')]);
        _stubHasMorePending(repo);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer(
          (_) => Future<bool>.delayed(
            const Duration(milliseconds: 100),
            () => true,
          ),
        );

        final events = _captureEvents(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          retryDelayOverride: const Duration(milliseconds: 200),
          sendTimeoutOverride: const Duration(milliseconds: 50),
        );

        OutboxProcessingResult? result;
        unawaited(proc.processQueue().then((r) => result = r));
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();
        expect(result, isNotNull);
        expect(events.any((e) => e.contains('timedOut=true')), isTrue);
      });
    });

    test('fast failure logs timedOut=false', () async {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      _stubClaimSequence(repo, [_item(id: 4, subject: 'host:fastfail')]);
      _stubHasMorePending(repo);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => sender.send(any())).thenAnswer((_) async => false);

      final events = _captureEvents(log);

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
        retryDelayOverride: const Duration(milliseconds: 200),
        sendTimeoutOverride: const Duration(milliseconds: 50),
      );

      final result = await proc.processQueue();
      expect(result.shouldSchedule, isTrue);
      expect(events.any((e) => e.contains('timedOut=false')), isTrue);
    });
  });

  test('send completing at exact timeout boundary doesnt race', () async {
    fakeAsync((async) {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      _stubClaimSequence(repo, [
        _item(id: 99, subject: 'host:timeout-boundary'),
      ]);
      _stubHasMorePending(repo);
      when(() => repo.markRetry(any())).thenAnswer((_) async {});
      when(() => repo.markSent(any())).thenAnswer((_) async {});
      // Complete exactly at timeout boundary (50ms)
      when(() => sender.send(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return true;
      });
      _stubSilentLogging(log);

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
        sendTimeoutOverride: const Duration(milliseconds: 50),
      );

      OutboxProcessingResult? result;
      unawaited(proc.processQueue().then((r) => result = r));
      async
        ..elapse(const Duration(milliseconds: 55))
        ..flushMicrotasks();
      expect(result, isNotNull);
      // At the exact timeout boundary, the send that completes should be
      // treated as success. Require a deterministic outcome:
      verify(() => repo.markSent(any())).called(1);
      verifyNever(() => repo.markRetry(any()));
    });
  });

  test('repeated failure counter handles large values', () async {
    final repo = MockOutboxRepository();
    final sender = MockMessageSender();
    final log = MockLoggingService();

    final item = _item(id: 1000, subject: 'S', messageId: 'repeat');
    // Claim the same item repeatedly to simulate the retry loop.
    when(
      () => repo.claim(leaseDuration: any(named: 'leaseDuration')),
    ).thenAnswer((_) async => item);
    _stubHasMorePending(repo);
    when(() => repo.markRetry(any())).thenAnswer((_) async {});
    when(() => sender.send(any())).thenAnswer((_) async => false);

    final events = _captureEvents(log);

    final proc = OutboxProcessor(
      repository: repo,
      messageSender: sender,
      loggingService: log,
    );

    for (var i = 0; i < 1000; i++) {
      await proc.processQueue();
    }

    final last = events.lastWhere(
      (e) => e.contains('sendFailed subject=S'),
      orElse: () => '',
    );
    expect(last, contains('repeats=1000'));
    expect(last.contains('repeats=-'), isFalse);
  });

  group('repeated failure diagnostics', () {
    test(
      'repeated failure increments repeats counter for same subject',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final item0 = _item(id: 21, subject: 'S', messageId: 'X');
        final item1 = item0.copyWith(
          retries: 1,
          updatedAt: DateTime(2024, 1, 2),
        );
        final item2 = item0.copyWith(
          retries: 2,
          updatedAt: DateTime(2024, 1, 3),
        );

        _stubClaimSequence(repo, [item0, item1, item2]);
        _stubHasMorePending(repo);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);

        final events = _captureEvents(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
        );

        await proc.processQueue();
        await proc.processQueue();
        await proc.processQueue();

        // Look for repeats=1, 2, 3 in sendFailed logs
        final r1 = events.any(
          (e) => e.contains('sendFailed') && e.contains('repeats=1'),
        );
        final r2 = events.any(
          (e) => e.contains('sendFailed') && e.contains('repeats=2'),
        );
        final r3 = events.any(
          (e) => e.contains('sendFailed') && e.contains('repeats=3'),
        );
        expect(r1 && r2 && r3, isTrue);
      },
    );

    test('repeated failure resets on different subject', () async {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      final a0 = _item(id: 31, subject: 'A', messageId: 'A');
      final a1 = a0.copyWith(retries: 1);
      final b0 = _item(id: 32, subject: 'B', messageId: 'B');

      _stubClaimSequence(repo, [a0, a1, b0]);
      _stubHasMorePending(repo);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => sender.send(any())).thenAnswer((_) async => false);

      final events = _captureEvents(log);

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
      );
      await proc.processQueue(); // A repeats=1
      await proc.processQueue(); // A repeats=2
      await proc.processQueue(); // B repeats=1 (reset)

      final hasA2 = events.any(
        (e) => e.contains('sendFailed subject=A') && e.contains('repeats=2'),
      );
      final hasB1 = events.any(
        (e) => e.contains('sendFailed subject=B') && e.contains('repeats=1'),
      );
      expect(hasA2 && hasB1, isTrue);
    });

    test('repeated failure resets on success for the same subject', () async {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      final s0 = _item(id: 41, subject: 'S', messageId: 'S');
      final s1 = s0.copyWith(retries: 1);
      final s2 = s0.copyWith(updatedAt: DateTime(2024, 2));

      var call = 0;
      when(
        () => repo.claim(leaseDuration: any(named: 'leaseDuration')),
      ).thenAnswer((_) async {
        call++;
        return call == 1
            ? s0
            : call == 2
            ? s1
            : call == 3
            ? s2
            : s0; // 4th call after reset
      });
      _stubHasMorePending(repo);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
      // First two tries fail, third succeeds
      var sendCall = 0;
      when(() => sender.send(any())).thenAnswer((_) async {
        sendCall++;
        return sendCall >= 3; // success on the 3rd call
      });

      final events = _captureEvents(log);

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
      );
      await proc.processQueue(); // S repeats=1
      await proc.processQueue(); // S repeats=2
      await proc.processQueue(); // success, reset

      // Now fail again for same subject; should start at repeats=1
      when(() => sender.send(any())).thenAnswer((_) async => false);
      await proc.processQueue();

      final hadRepeats2 = events.any(
        (e) => e.contains('sendFailed subject=S') && e.contains('repeats=2'),
      );
      final hadRepeats1AfterSuccess = events
          .lastWhere(
            (e) => e.contains('sendFailed subject=S'),
            orElse: () => '',
          )
          .contains('repeats=1');
      expect(hadRepeats2 && hadRepeats1AfterSuccess, isTrue);
    });
  });

  test(
    'post-markSent exception does not revive the row via markRetry',
    () async {
      // Regression guard: if the post-send observability path (hasMorePending
      // or the captureEvent log line) throws AFTER markSent has committed,
      // the exception handler must NOT call markRetry — that would flip the
      // already-sent row back to pending and cause a duplicate Matrix event.
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      _stubClaimSequence(repo, [_item(subject: 'host:post-mark')]);
      when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => sender.send(any())).thenAnswer((_) async => true);
      // hasMorePending throws post-markSent.
      when(repo.hasMorePending).thenThrow(Exception('post-send boom'));
      _stubSilentLogging(log);

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
      );

      final result = await proc.processQueue();

      verify(() => repo.markSent(any())).called(1);
      verifyNever(() => repo.markRetry(any()));
      expect(result.shouldSchedule, isTrue);
      expect(result.nextDelay, Duration.zero);
    },
  );

  group('claim semantics', () {
    test(
      'uses the message content returned by claim, not an earlier read',
      () async {
        // Regression guard for the merge-send race: the repository's claim()
        // returns the current (potentially just-merged) message for the row;
        // the processor must send that content verbatim, not any stale
        // snapshot read earlier in the pipeline.
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final claimedItem = OutboxItem(
          id: 100,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'new-version').toJson(),
          ),
          subject: 'host:claim',
          status: OutboxStatus.sending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024, 1, 2),
          priority: OutboxPriority.low.index,
        );

        _stubClaimSequence(repo, [claimedItem]);
        _stubHasMorePending(repo);
        when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});

        SyncMessage? sentMessage;
        when(() => sender.send(any())).thenAnswer((inv) async {
          sentMessage = inv.positionalArguments.first as SyncMessage;
          return true;
        });
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
        );

        await proc.processQueue();

        expect(sentMessage, isNotNull);
        expect(
          sentMessage,
          isA<SyncAiConfigDelete>().having(
            (m) => m.id,
            'id',
            equals('new-version'),
          ),
        );
        verify(() => repo.markSent(claimedItem)).called(1);
      },
    );
  });
}
