import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockMessageSender extends Mock implements OutboxMessageSender {}

class MockLogging extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      OutboxItem(
        id: 1,
        message: '{}',
        subject: 's',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'x'));
    registerFallbackValue(StackTrace.empty);
  });

  test('send timeout triggers retry and schedules backoff', () async {
    fakeAsync((async) {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLogging();

      final pending = OutboxItem(
        id: 1,
        // Use valid JSON encoding for the stored message payload
        message:
            jsonEncode(const SyncMessage.aiConfigDelete(id: 'cfg').toJson()),
        subject: 'host:1',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      when(() => repo.fetchPending(limit: any<int>(named: 'limit')))
          .thenAnswer((_) async => [pending]);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      // Sender never completes; processQueue relies on the timeout
      when(() => sender.send(any()))
          .thenAnswer((_) => Completer<bool>().future);
      when(() => log.captureEvent(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((_) {});
      when(() => log.captureException(any<Object>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
              stackTrace: any<StackTrace?>(named: 'stackTrace')))
          .thenAnswer((_) async {});

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

  group('retry cap', () {
    test('retry cap on send failure advances queue (delay=0) and logs', () {
      fakeAsync((async) {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLogging();

        final pending = OutboxItem(
          id: 1,
          message:
              jsonEncode(const SyncMessage.aiConfigDelete(id: 'cfg').toJson()),
          subject: 'host:cap',
          status: OutboxStatus.pending.index,
          retries: 2, // maxRetriesOverride=3 → nextAttempts=3 hits cap
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        when(() => repo.fetchPending(limit: any(named: 'limit')))
            .thenAnswer((_) async => [pending]);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);
        final events = <String>[];
        when(() => log.captureEvent(captureAny<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'))).thenAnswer((inv) {
          events.add(inv.positionalArguments.first.toString());
        });

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
        verify(() => log.captureEvent(
              startsWith('retryCapReached subject=host:cap attempts=3'),
              domain: 'OUTBOX',
              subDomain: 'retry.cap',
            )).called(1);
        expect(
          events.any((e) =>
              e.contains('retryCapReached subject=host:cap attempts=3') &&
              e.contains('status=error')),
          isTrue,
        );
      });
    });

    test('retry cap on exception advances queue and logs', () {
      fakeAsync((async) {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLogging();

        final pending = OutboxItem(
          id: 2,
          message:
              jsonEncode(const SyncMessage.aiConfigDelete(id: 'cfg').toJson()),
          subject: 'host:cap-ex',
          status: OutboxStatus.pending.index,
          retries: 2,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        when(() => repo.fetchPending(limit: any(named: 'limit')))
            .thenAnswer((_) async => [pending]);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenThrow(Exception('boom'));
        final events = <String>[];
        when(() => log.captureEvent(captureAny<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'))).thenAnswer((inv) {
          events.add(inv.positionalArguments.first.toString());
        });
        when(() => log.captureException(
              any<Object>(),
              domain: any(named: 'domain'),
              subDomain: any(named: 'subDomain'),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            )).thenAnswer((_) async {});

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
        verify(() => log.captureEvent(
              startsWith('retryCapReached subject=host:cap-ex attempts=3'),
              domain: 'OUTBOX',
              subDomain: 'retry.cap',
            )).called(1);
        expect(
          events.any((e) =>
              e.contains('retryCapReached subject=host:cap-ex attempts=3') &&
              e.contains('status=error')),
          isTrue,
        );
      });
    });

    test('queue continues processing after capped item', () async {
      // First call returns item A at cap (retries=2, max=3), second call returns item B
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLogging();

      final a = OutboxItem(
        id: 11,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'A').toJson()),
        subject: 'A',
        status: OutboxStatus.pending.index,
        retries: 2,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final b = OutboxItem(
        id: 12,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'B').toJson()),
        subject: 'B',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      var call = 0;
      when(() => repo.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        call++;
        return call == 1 ? [a] : [b];
      });
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
      var sendCalls = 0;
      when(() => sender.send(any())).thenAnswer((_) async {
        sendCalls++;
        // First call (A) fails at cap; second call (B) succeeds
        return sendCalls == 2;
      });
      when(() => log.captureEvent(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((_) {});

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
        maxRetriesOverride: 3,
      );

      final r1 = await proc.processQueue();
      expect(
          r1.nextDelay, Duration.zero); // cap reached → immediate continuation
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
        final log = MockLogging();

        final pending = OutboxItem(
          id: 3,
          message:
              jsonEncode(const SyncMessage.aiConfigDelete(id: 'cfg').toJson()),
          subject: 'host:slow',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );
        when(() => repo.fetchPending(limit: any(named: 'limit')))
            .thenAnswer((_) async => [pending]);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) => Future<bool>.delayed(
            const Duration(milliseconds: 100), () => true));

        final events = <String>[];
        when(() => log.captureEvent(captureAny<Object>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'))).thenAnswer((inv) {
          events.add(inv.positionalArguments.first.toString());
        });

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
      final log = MockLogging();

      final pending = OutboxItem(
        id: 4,
        message:
            jsonEncode(const SyncMessage.aiConfigDelete(id: 'cfg').toJson()),
        subject: 'host:fastfail',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      when(() => repo.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [pending]);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => sender.send(any())).thenAnswer((_) async => false);

      final events = <String>[];
      when(() => log.captureEvent(captureAny<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'))).thenAnswer((inv) {
        events.add(inv.positionalArguments.first.toString());
      });

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
      final log = MockLogging();

      final pending = OutboxItem(
        id: 99,
        message:
            jsonEncode(const SyncMessage.aiConfigDelete(id: 'cfg').toJson()),
        subject: 'host:timeout-boundary',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      when(() => repo.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [pending]);
      when(() => repo.markRetry(any())).thenAnswer((_) async {});
      when(() => repo.markSent(any())).thenAnswer((_) async {});
      // Complete exactly at timeout boundary (50ms)
      when(() => sender.send(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return true;
      });
      when(() => log.captureEvent(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((_) {});

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
    final log = MockLogging();

    final item = OutboxItem(
      id: 1000,
      message:
          jsonEncode(const SyncMessage.aiConfigDelete(id: 'repeat').toJson()),
      subject: 'S',
      status: OutboxStatus.pending.index,
      retries: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    when(() => repo.fetchPending(limit: any(named: 'limit')))
        .thenAnswer((_) async => [item]);
    when(() => repo.markRetry(any())).thenAnswer((_) async {});
    when(() => sender.send(any())).thenAnswer((_) async => false);

    final events = <String>[];
    when(() => log.captureEvent(captureAny<Object>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'))).thenAnswer((inv) {
      events.add(inv.positionalArguments.first.toString());
    });

    final proc = OutboxProcessor(
      repository: repo,
      messageSender: sender,
      loggingService: log,
    );

    // Fail same head-of-queue subject many times
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
    test('repeated failure increments repeats counter for same subject',
        () async {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLogging();

      // First failure: retries=0 → nextAttempts=1, repeats=1
      final item0 = OutboxItem(
        id: 21,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'X').toJson()),
        subject: 'S',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      // Second failure: same subject, retries=1 → repeats=2
      final item1 = item0.copyWith(retries: 1, updatedAt: DateTime(2024, 1, 2));
      // Third failure: same subject, retries=2 → repeats=3
      final item2 = item0.copyWith(retries: 2, updatedAt: DateTime(2024, 1, 3));

      var call = 0;
      when(() => repo.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        call++;
        return call == 1
            ? [item0]
            : call == 2
                ? [item1]
                : [item2];
      });
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => sender.send(any())).thenAnswer((_) async => false);

      final events = <String>[];
      when(() => log.captureEvent(captureAny<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'))).thenAnswer((inv) {
        events.add(inv.positionalArguments.first.toString());
      });

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
      );

      await proc.processQueue();
      await proc.processQueue();
      await proc.processQueue();

      // Look for repeats=1, 2, 3 in sendFailed logs
      final r1 = events
          .any((e) => e.contains('sendFailed') && e.contains('repeats=1'));
      final r2 = events
          .any((e) => e.contains('sendFailed') && e.contains('repeats=2'));
      final r3 = events
          .any((e) => e.contains('sendFailed') && e.contains('repeats=3'));
      expect(r1 && r2 && r3, isTrue);
    });

    test('repeated failure resets on different subject', () async {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLogging();

      final a0 = OutboxItem(
        id: 31,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'A').toJson()),
        subject: 'A',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final a1 = a0.copyWith(retries: 1);
      final b0 = OutboxItem(
        id: 32,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'B').toJson()),
        subject: 'B',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      var call = 0;
      when(() => repo.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        call++;
        return call == 1
            ? [a0]
            : call == 2
                ? [a1]
                : [b0];
      });
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => sender.send(any())).thenAnswer((_) async => false);

      final events = <String>[];
      when(() => log.captureEvent(captureAny<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'))).thenAnswer((inv) {
        events.add(inv.positionalArguments.first.toString());
      });

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
      );
      await proc.processQueue(); // A repeats=1
      await proc.processQueue(); // A repeats=2
      await proc.processQueue(); // B repeats=1 (reset)

      final hasA2 = events.any(
          (e) => e.contains('sendFailed subject=A') && e.contains('repeats=2'));
      final hasB1 = events.any(
          (e) => e.contains('sendFailed subject=B') && e.contains('repeats=1'));
      expect(hasA2 && hasB1, isTrue);
    });

    test('repeated failure resets on success for the same subject', () async {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLogging();

      final s0 = OutboxItem(
        id: 41,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'S').toJson()),
        subject: 'S',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      final s1 = s0.copyWith(retries: 1);
      final s2 = s0.copyWith(updatedAt: DateTime(2024, 2));

      var call = 0;
      when(() => repo.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        call++;
        return call == 1
            ? [s0]
            : call == 2
                ? [s1]
                : [s2];
      });
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
      // First two tries fail, third succeeds
      var sendCall = 0;
      when(() => sender.send(any())).thenAnswer((_) async {
        sendCall++;
        return sendCall >= 3; // success on the 3rd call
      });

      final events = <String>[];
      when(() => log.captureEvent(captureAny<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'))).thenAnswer((inv) {
        events.add(inv.positionalArguments.first.toString());
      });

      final proc = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
      );
      await proc.processQueue(); // S repeats=1
      await proc.processQueue(); // S repeats=2
      await proc.processQueue(); // success, reset

      // Now fail again for same subject; should start at repeats=1
      when(() => repo.fetchPending(limit: any(named: 'limit')))
          .thenAnswer((_) async => [s0]);
      when(() => sender.send(any())).thenAnswer((_) async => false);
      await proc.processQueue();

      final hadRepeats2 = events.any(
          (e) => e.contains('sendFailed subject=S') && e.contains('repeats=2'));
      final hadRepeats1AfterSuccess = events
          .lastWhere((e) => e.contains('sendFailed subject=S'),
              orElse: () => '')
          .contains('repeats=1');
      expect(hadRepeats2 && hadRepeats1AfterSuccess, isTrue);
    });
  });
}
