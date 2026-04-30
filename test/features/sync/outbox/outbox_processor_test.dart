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

  group('bundle path', () {
    OutboxItem textItem({required int id, String subject = 'host:t'}) {
      return OutboxItem(
        id: id,
        message: jsonEncode(
          SyncMessage.aiConfigDelete(id: 'cfg-$id').toJson(),
        ),
        subject: '$subject:$id',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024).add(Duration(minutes: id)),
        updatedAt: DateTime(2024).add(Duration(minutes: id)),
        priority: OutboxPriority.low.index,
      );
    }

    OutboxItem mediaItem({required int id, String subject = 'media'}) {
      return OutboxItem(
        id: id,
        message: jsonEncode(
          SyncMessage.aiConfigDelete(id: 'media-$id').toJson(),
        ),
        subject: '$subject:$id',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024).add(Duration(minutes: id)),
        updatedAt: DateTime(2024).add(Duration(minutes: id)),
        filePath: 'images/$id.jpg',
        priority: OutboxPriority.high.index,
      );
    }

    /// Models `claimNextBatch` against an in-memory pending queue: the head
    /// row is returned alone when it is a media attachment, otherwise the
    /// maximal text-only prefix capped at [maxSize].
    void stubBatchClaimFromQueue(
      MockOutboxRepository repo,
      List<OutboxItem> queue,
    ) {
      when(
        () => repo.claimNextBatch(
          maxSize: any(named: 'maxSize'),
          leaseDuration: any(named: 'leaseDuration'),
        ),
      ).thenAnswer((invocation) async {
        if (queue.isEmpty) return <OutboxItem>[];
        final maxSize = invocation.namedArguments[#maxSize] as int;
        if (queue.first.filePath != null) {
          return [queue.removeAt(0)];
        }
        final stopAt = queue.indexWhere((row) => row.filePath != null);
        final boundary = stopAt == -1 ? queue.length : stopAt;
        final cap = boundary < maxSize ? boundary : maxSize;
        final claimed = queue.sublist(0, cap);
        queue.removeRange(0, cap);
        return claimed;
      });
      when(() => repo.hasMorePending()).thenAnswer(
        (_) async => queue.isNotEmpty,
      );
    }

    test(
      'bundling disabled by default — claim() is used, never claimNextBatch',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        _stubClaimSequence(repo, [textItem(id: 1)]);
        _stubHasMorePending(repo);
        when(() => repo.markSent(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => true);
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
        );

        await proc.processQueue();

        verify(
          () => repo.claim(leaseDuration: any(named: 'leaseDuration')),
        ).called(1);
        verifyNever(
          () => repo.claimNextBatch(
            maxSize: any(named: 'maxSize'),
            leaseDuration: any(named: 'leaseDuration'),
          ),
        );
      },
    );

    test(
      'when the bundle provider yields 1, the legacy claim() path is used '
      '(boundary case — proves no behavior drift when the flag is off)',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        _stubClaimSequence(repo, [textItem(id: 1)]);
        _stubHasMorePending(repo);
        when(() => repo.markSent(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => true);
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          bundleMaxSizeProvider: () async => 1,
        );

        await proc.processQueue();

        verify(
          () => repo.claim(leaseDuration: any(named: 'leaseDuration')),
        ).called(1);
        verifyNever(
          () => repo.claimNextBatch(
            maxSize: any(named: 'maxSize'),
            leaseDuration: any(named: 'leaseDuration'),
          ),
        );
      },
    );

    test(
      'a single-row batch of text routes through the single-item path '
      '(no bundle envelope is constructed, so the wire format is unchanged '
      'when only one row is pending)',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = [textItem(id: 1)];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markSent(any())).thenAnswer((_) async {});
        SyncMessage? sent;
        when(() => sender.send(any())).thenAnswer((inv) async {
          sent = inv.positionalArguments[0] as SyncMessage;
          return true;
        });
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          bundleMaxSizeProvider: () async => 50,
        );

        await proc.processQueue();

        expect(sent, isA<SyncAiConfigDelete>());
        verify(() => repo.markSent(any())).called(1);
        verifyNever(() => repo.markSentBatch(any()));
      },
    );

    test(
      'a single-row batch of a media attachment also routes through the '
      'single-item path — attachments never travel inside a bundle',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = [mediaItem(id: 1)];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markSent(any())).thenAnswer((_) async {});
        SyncMessage? sent;
        when(() => sender.send(any())).thenAnswer((inv) async {
          sent = inv.positionalArguments[0] as SyncMessage;
          return true;
        });
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          bundleMaxSizeProvider: () async => 50,
        );

        await proc.processQueue();

        expect(sent, isNot(isA<SyncOutboxBundle>()));
        verify(() => repo.markSent(any())).called(1);
        verifyNever(() => repo.markSentBatch(any()));
      },
    );

    test(
      'a multi-row batch is wrapped in a SyncOutboxBundle and committed via '
      'markSentBatch on success',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = [
          for (var i = 1; i <= 5; i++) textItem(id: i),
        ];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markSentBatch(any())).thenAnswer((_) async {});
        SyncMessage? sent;
        when(() => sender.send(any())).thenAnswer((inv) async {
          sent = inv.positionalArguments[0] as SyncMessage;
          return true;
        });
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          bundleMaxSizeProvider: () async => 50,
        );

        final result = await proc.processQueue();

        final bundle = sent! as SyncOutboxBundle;
        expect(bundle.children, hasLength(5));
        for (final child in bundle.children) {
          expect(child, isA<SyncAiConfigDelete>());
        }
        verify(
          () => repo.markSentBatch(
            any(
              that: isA<List<OutboxItem>>().having((b) => b.length, 'len', 5),
            ),
          ),
        ).called(1);
        verifyNever(() => repo.markSent(any()));
        expect(result.shouldSchedule, isFalse);
      },
    );

    test(
      'on bundle send failure every row in the batch goes through markRetryBatch '
      'and the result schedules the standard retry backoff',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = [
          for (var i = 1; i <= 3; i++) textItem(id: i),
        ];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markRetryBatch(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          retryDelayOverride: const Duration(milliseconds: 250),
          bundleMaxSizeProvider: () async => 50,
        );

        final result = await proc.processQueue();

        verify(
          () => repo.markRetryBatch(
            any(
              that: isA<List<OutboxItem>>().having((b) => b.length, 'len', 3),
            ),
          ),
        ).called(1);
        verifyNever(() => repo.markRetry(any()));
        expect(result.shouldSchedule, isTrue);
        expect(result.nextDelay, const Duration(milliseconds: 250));
      },
    );

    test(
      'bundle retry-cap fast-path: when any row in the batch crosses '
      'maxRetriesForDiagnostics on its incremented retry count, the next '
      'drain is scheduled at delay=0 so the queue advances past the '
      'now-errored rows immediately',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final hotRow = textItem(id: 1).copyWith(retries: 1);
        final coldRow = textItem(id: 2);
        final queue = [hotRow, coldRow];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markRetryBatch(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          maxRetriesOverride: 2,
          retryDelayOverride: const Duration(seconds: 5),
          bundleMaxSizeProvider: () async => 50,
        );

        final result = await proc.processQueue();

        expect(result.shouldSchedule, isTrue);
        expect(result.nextDelay, Duration.zero);
        verify(() => repo.markRetryBatch(any())).called(1);
      },
    );

    test(
      'bundle send timeout is treated identically to a soft failure: the '
      'whole batch flips to retry via markRetryBatch and the standard '
      'backoff is scheduled',
      () async {
        fakeAsync((async) {
          final repo = MockOutboxRepository();
          final sender = MockMessageSender();
          final log = MockLoggingService();

          final queue = [
            for (var i = 1; i <= 4; i++) textItem(id: i),
          ];
          stubBatchClaimFromQueue(repo, queue);
          when(() => repo.markRetryBatch(any())).thenAnswer((_) async {});
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
            bundleMaxSizeProvider: () async => 50,
          );

          OutboxProcessingResult? result;
          unawaited(proc.processQueue().then((r) => result = r));
          async
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks();
          expect(result, isNotNull);
          expect(result!.shouldSchedule, isTrue);
          expect(result!.nextDelay?.inMilliseconds, 200);
          verify(() => repo.markRetryBatch(any())).called(1);
        });
      },
    );

    test(
      'bundle send raising an exception in the post-send observability path '
      'does not revive the row through markRetryBatch — once markSentBatch '
      'has succeeded the rows are considered acknowledged',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = [
          for (var i = 1; i <= 3; i++) textItem(id: i),
        ];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markSentBatch(any())).thenAnswer((_) async {});
        // hasMorePending throws AFTER markSentBatch already committed.
        // mocktail requires the closure form so the call is captured for
        // stubbing; a tearoff would invoke the method on the spot.
        // ignore: unnecessary_lambdas
        when(() => repo.hasMorePending()).thenThrow(StateError('boom'));
        when(() => sender.send(any())).thenAnswer((_) async => true);
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          bundleMaxSizeProvider: () async => 50,
        );

        final result = await proc.processQueue();

        verify(() => repo.markSentBatch(any())).called(1);
        verifyNever(() => repo.markRetryBatch(any()));
        expect(result.shouldSchedule, isTrue);
        expect(result.nextDelay, Duration.zero);
      },
    );

    test(
      'Scenario A reproduction (image at position 100 in a 500-row queue): '
      'the wire pattern is bundle(50) × 2 → image alone → bundle(50) × 8 — '
      '500 rows ship in 11 sends instead of 500',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = <OutboxItem>[
          for (var i = 1; i < 100; i++) textItem(id: i),
          mediaItem(id: 100),
          for (var i = 101; i <= 500; i++) textItem(id: i),
        ];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markSent(any())).thenAnswer((_) async {});
        when(() => repo.markSentBatch(any())).thenAnswer((_) async {});

        final sends = <SyncMessage>[];
        when(() => sender.send(any())).thenAnswer((inv) async {
          sends.add(inv.positionalArguments[0] as SyncMessage);
          return true;
        });
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          bundleMaxSizeProvider: () async => 50,
        );

        // Drain until processQueue reports nothing more to do.
        var safety = 1000;
        while (safety-- > 0) {
          final r = await proc.processQueue();
          if (!r.shouldSchedule) break;
        }
        expect(safety, greaterThan(0), reason: 'drain loop did not terminate');

        // Bucket the sends by their wire shape.
        final bundleSizes = <int>[];
        var imagesSent = 0;
        for (final s in sends) {
          if (s is SyncOutboxBundle) {
            bundleSizes.add(s.children.length);
          } else {
            imagesSent++;
          }
        }

        expect(imagesSent, 1, reason: 'one media attachment, sent alone');
        // First two bundles fill to 50 (rows 1..50, 51..99 = 49 — head fills
        // then stops at the attachment), then image, then 8 × 50 to drain
        // 401..500.
        expect(bundleSizes.first, 50);
        expect(
          bundleSizes,
          orderedEquals([50, 49, 50, 50, 50, 50, 50, 50, 50, 50]),
          reason: '500 rows + image at pos 100 → bundle pattern',
        );
        expect(sends.length, 11);
      },
    );

    test(
      'Scenario B reproduction (image at position 60): pattern is '
      'bundle(50) → bundle(9) → image alone',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = <OutboxItem>[
          for (var i = 1; i <= 59; i++) textItem(id: i),
          mediaItem(id: 60),
        ];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markSent(any())).thenAnswer((_) async {});
        when(() => repo.markSentBatch(any())).thenAnswer((_) async {});

        final sends = <SyncMessage>[];
        when(() => sender.send(any())).thenAnswer((inv) async {
          sends.add(inv.positionalArguments[0] as SyncMessage);
          return true;
        });
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          bundleMaxSizeProvider: () async => 50,
        );

        var safety = 100;
        while (safety-- > 0) {
          final r = await proc.processQueue();
          if (!r.shouldSchedule) break;
        }
        expect(safety, greaterThan(0));

        expect(sends, hasLength(3));
        expect((sends[0] as SyncOutboxBundle).children, hasLength(50));
        expect((sends[1] as SyncOutboxBundle).children, hasLength(9));
        expect(sends[2], isNot(isA<SyncOutboxBundle>()));
      },
    );

    test(
      'a flag-read failure inside the provider falls back to single-row '
      'behavior — the outbox never blocks on a transient flag read',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        _stubClaimSequence(repo, [textItem(id: 1)]);
        _stubHasMorePending(repo);
        when(() => repo.markSent(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => true);
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          // The OutboxService.resolveBundleMaxSize wrapper catches the
          // exception and returns 1; here we model the same fallback.
          bundleMaxSizeProvider: () async => 1,
        );

        final result = await proc.processQueue();

        expect(result.shouldSchedule, isFalse);
        verify(
          () => repo.claim(leaseDuration: any(named: 'leaseDuration')),
        ).called(1);
        verifyNever(
          () => repo.claimNextBatch(
            maxSize: any(named: 'maxSize'),
            leaseDuration: any(named: 'leaseDuration'),
          ),
        );
      },
    );
  });
}
