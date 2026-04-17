import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_processor.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockOutboxRepository extends Mock implements OutboxRepository {}

class MockMessageSender extends Mock implements OutboxMessageSender {}

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
        priority: OutboxPriority.low.index,
      ),
    );
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'x'));
    registerFallbackValue(StackTrace.empty);
  });

  test('send timeout triggers retry and schedules backoff', () async {
    fakeAsync((async) {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      final pending = OutboxItem(
        id: 1,
        // Use valid JSON encoding for the stored message payload
        message: jsonEncode(
          const SyncMessage.aiConfigDelete(id: 'cfg').toJson(),
        ),
        subject: 'host:1',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        priority: OutboxPriority.low.index,
      );
      when(
        () => repo.fetchPending(limit: any<int>(named: 'limit')),
      ).thenAnswer((_) async => [pending]);
      when(
        () => repo.refreshItem(any<OutboxItem>()),
      ).thenAnswer((_) async => pending);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      // Sender never completes; processQueue relies on the timeout
      when(
        () => sender.send(any()),
      ).thenAnswer((_) => Completer<bool>().future);
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
        final log = MockLoggingService();

        final pending = OutboxItem(
          id: 1,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'cfg').toJson(),
          ),
          subject: 'host:cap',
          status: OutboxStatus.pending.index,
          retries: 2, // maxRetriesOverride=3 → nextAttempts=3 hits cap
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          priority: OutboxPriority.low.index,
        );

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [pending]);
        when(
          () => repo.refreshItem(any<OutboxItem>()),
        ).thenAnswer((_) async => pending);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);
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

        final pending = OutboxItem(
          id: 2,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'cfg').toJson(),
          ),
          subject: 'host:cap-ex',
          status: OutboxStatus.pending.index,
          retries: 2,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          priority: OutboxPriority.low.index,
        );

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [pending]);
        when(
          () => repo.refreshItem(any<OutboxItem>()),
        ).thenAnswer((_) async => pending);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenThrow(Exception('boom'));
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
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

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
      // First call returns item A at cap (retries=2, max=3), second call returns item B
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();

      final a = OutboxItem(
        id: 11,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'A').toJson()),
        subject: 'A',
        status: OutboxStatus.pending.index,
        retries: 2,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        priority: OutboxPriority.low.index,
      );
      final b = OutboxItem(
        id: 12,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'B').toJson()),
        subject: 'B',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        priority: OutboxPriority.low.index,
      );

      var call = 0;
      when(() => repo.fetchPending(limit: any(named: 'limit'))).thenAnswer((
        _,
      ) async {
        call++;
        return call == 1 ? [a] : [b];
      });
      var refreshCall = 0;
      when(() => repo.refreshItem(any<OutboxItem>())).thenAnswer((_) async {
        refreshCall++;
        return refreshCall == 1 ? a : b;
      });
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
      var sendCalls = 0;
      when(() => sender.send(any())).thenAnswer((_) async {
        sendCalls++;
        // First call (A) fails at cap; second call (B) succeeds
        return sendCalls == 2;
      });
      when(
        () => log.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

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

        final pending = OutboxItem(
          id: 3,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'cfg').toJson(),
          ),
          subject: 'host:slow',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          priority: OutboxPriority.low.index,
        );
        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [pending]);
        when(
          () => repo.refreshItem(any<OutboxItem>()),
        ).thenAnswer((_) async => pending);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer(
          (_) => Future<bool>.delayed(
            const Duration(milliseconds: 100),
            () => true,
          ),
        );

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

      final pending = OutboxItem(
        id: 4,
        message: jsonEncode(
          const SyncMessage.aiConfigDelete(id: 'cfg').toJson(),
        ),
        subject: 'host:fastfail',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        priority: OutboxPriority.low.index,
      );
      when(
        () => repo.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer((_) async => [pending]);
      when(
        () => repo.refreshItem(any<OutboxItem>()),
      ).thenAnswer((_) async => pending);
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => sender.send(any())).thenAnswer((_) async => false);

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

      final pending = OutboxItem(
        id: 99,
        message: jsonEncode(
          const SyncMessage.aiConfigDelete(id: 'cfg').toJson(),
        ),
        subject: 'host:timeout-boundary',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        priority: OutboxPriority.low.index,
      );
      when(
        () => repo.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer((_) async => [pending]);
      when(
        () => repo.refreshItem(any<OutboxItem>()),
      ).thenAnswer((_) async => pending);
      when(() => repo.markRetry(any())).thenAnswer((_) async {});
      when(() => repo.markSent(any())).thenAnswer((_) async {});
      // Complete exactly at timeout boundary (50ms)
      when(() => sender.send(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return true;
      });
      when(
        () => log.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});

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

    final item = OutboxItem(
      id: 1000,
      message: jsonEncode(
        const SyncMessage.aiConfigDelete(id: 'repeat').toJson(),
      ),
      subject: 'S',
      status: OutboxStatus.pending.index,
      retries: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      priority: OutboxPriority.low.index,
    );
    when(
      () => repo.fetchPending(limit: any(named: 'limit')),
    ).thenAnswer((_) async => [item]);
    when(
      () => repo.refreshItem(any<OutboxItem>()),
    ).thenAnswer((_) async => item);
    when(() => repo.markRetry(any())).thenAnswer((_) async {});
    when(() => sender.send(any())).thenAnswer((_) async => false);

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
    test(
      'repeated failure increments repeats counter for same subject',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        // First failure: retries=0 → nextAttempts=1, repeats=1
        final item0 = OutboxItem(
          id: 21,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'X').toJson(),
          ),
          subject: 'S',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          priority: OutboxPriority.low.index,
        );
        // Second failure: same subject, retries=1 → repeats=2
        final item1 = item0.copyWith(
          retries: 1,
          updatedAt: DateTime(2024, 1, 2),
        );
        // Third failure: same subject, retries=2 → repeats=3
        final item2 = item0.copyWith(
          retries: 2,
          updatedAt: DateTime(2024, 1, 3),
        );

        var call = 0;
        when(() => repo.fetchPending(limit: any(named: 'limit'))).thenAnswer((
          _,
        ) async {
          call++;
          return call == 1
              ? [item0]
              : call == 2
              ? [item1]
              : [item2];
        });
        var refreshCall = 0;
        when(() => repo.refreshItem(any<OutboxItem>())).thenAnswer((_) async {
          refreshCall++;
          return refreshCall == 1
              ? item0
              : refreshCall == 2
              ? item1
              : item2;
        });
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);

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

      final a0 = OutboxItem(
        id: 31,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'A').toJson()),
        subject: 'A',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        priority: OutboxPriority.low.index,
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
        priority: OutboxPriority.low.index,
      );

      var call = 0;
      when(() => repo.fetchPending(limit: any(named: 'limit'))).thenAnswer((
        _,
      ) async {
        call++;
        return call == 1
            ? [a0]
            : call == 2
            ? [a1]
            : [b0];
      });
      var refreshCall = 0;
      when(() => repo.refreshItem(any<OutboxItem>())).thenAnswer((_) async {
        refreshCall++;
        return refreshCall == 1
            ? a0
            : refreshCall == 2
            ? a1
            : b0;
      });
      when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
      when(() => sender.send(any())).thenAnswer((_) async => false);

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

      final s0 = OutboxItem(
        id: 41,
        message: jsonEncode(const SyncMessage.aiConfigDelete(id: 'S').toJson()),
        subject: 'S',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        priority: OutboxPriority.low.index,
      );
      final s1 = s0.copyWith(retries: 1);
      final s2 = s0.copyWith(updatedAt: DateTime(2024, 2));

      var call = 0;
      when(() => repo.fetchPending(limit: any(named: 'limit'))).thenAnswer((
        _,
      ) async {
        call++;
        return call == 1
            ? [s0]
            : call == 2
            ? [s1]
            : [s2];
      });
      var refreshCall = 0;
      when(() => repo.refreshItem(any<OutboxItem>())).thenAnswer((_) async {
        refreshCall++;
        return refreshCall == 1
            ? s0
            : refreshCall == 2
            ? s1
            : refreshCall == 3
            ? s2
            : s0; // 4th call after reset
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
      when(
        () => log.captureEvent(
          captureAny<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((inv) {
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
      when(
        () => repo.fetchPending(limit: any(named: 'limit')),
      ).thenAnswer((_) async => [s0]);
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

  group('refresh before send', () {
    test(
      'sends refreshed message when item updated between fetch and send',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        // Initial fetch returns item with old message
        final oldItem = OutboxItem(
          id: 100,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'old-version').toJson(),
          ),
          subject: 'host:refresh-test',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          priority: OutboxPriority.low.index,
        );

        // Refreshed item has updated message (simulating merge that happened)
        final refreshedItem = OutboxItem(
          id: 100,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'new-version').toJson(),
          ),
          subject: 'host:refresh-test',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024, 1, 2),
          priority: OutboxPriority.low.index,
        );

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [oldItem]);
        when(
          () => repo.refreshItem(any<OutboxItem>()),
        ).thenAnswer((_) async => refreshedItem);
        when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});

        // Capture what message was actually sent
        SyncMessage? sentMessage;
        when(() => sender.send(any())).thenAnswer((inv) async {
          sentMessage = inv.positionalArguments.first as SyncMessage;
          return true;
        });
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
        );

        await proc.processQueue();

        // Verify the NEW message was sent, not the old one
        expect(sentMessage, isNotNull);
        expect(
          sentMessage,
          isA<SyncAiConfigDelete>().having(
            (m) => m.id,
            'id',
            equals('new-version'),
          ),
        );
        verify(() => repo.markSent(refreshedItem)).called(1);
      },
    );

    test(
      'skips item when refreshItem returns null (item no longer pending)',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final item = OutboxItem(
          id: 101,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'skip').toJson(),
          ),
          subject: 'host:skip-test',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          priority: OutboxPriority.low.index,
        );

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        // refreshItem returns null - item was sent/deleted by another process
        when(
          () => repo.refreshItem(any<OutboxItem>()),
        ).thenAnswer((_) async => null);

        final events = <String>[];
        when(
          () => log.captureEvent(
            captureAny<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((inv) {
          events.add(inv.positionalArguments.first.toString());
        });

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
        );

        final result = await proc.processQueue();

        // Verify send was never called
        verifyNever(() => sender.send(any()));
        // Verify skip was logged
        expect(events.any((e) => e.contains('item no longer pending')), isTrue);
        // Result should indicate no more work (was only item)
        expect(result.shouldSchedule, isFalse);
      },
    );

    test(
      'continues to next item when current item becomes non-pending',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final item1 = OutboxItem(
          id: 102,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'first-skip').toJson(),
          ),
          subject: 'host:first',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          priority: OutboxPriority.low.index,
        );
        final item2 = OutboxItem(
          id: 103,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'second-send').toJson(),
          ),
          subject: 'host:second',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          priority: OutboxPriority.low.index,
        );

        // First fetch returns both items
        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item1, item2]);
        // First refresh returns null (item1 no longer pending), second returns item2
        var refreshCall = 0;
        when(() => repo.refreshItem(any<OutboxItem>())).thenAnswer((_) async {
          refreshCall++;
          return refreshCall == 1 ? null : item2;
        });
        when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => true);
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
        );

        // First call: item1 skipped because refresh returns null
        final result1 = await proc.processQueue();
        // Should schedule immediately (hasMore=true, item was skipped)
        expect(result1.shouldSchedule, isTrue);
        expect(result1.nextDelay, Duration.zero);

        // Second call would process item2 (new fetch)
        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item2]);
        final result2 = await proc.processQueue();
        // item2 sent successfully, no more items
        expect(result2.shouldSchedule, isFalse);
        verify(() => sender.send(any())).called(1);
      },
    );
  });

  group('attachment bundling', () {
    Metadata meta(String id) {
      final ts = DateTime(2026, 4, 17, 12);
      return Metadata(
        id: id,
        createdAt: ts,
        updatedAt: ts,
        dateFrom: ts,
        dateTo: ts,
      );
    }

    OutboxItem pendingFor({
      required int id,
      required String entryId,
      required String jsonPath,
    }) {
      return OutboxItem(
        id: id,
        message: jsonEncode(
          SyncMessage.journalEntity(
            id: entryId,
            jsonPath: jsonPath,
            vectorClock: null,
            status: SyncEntryStatus.initial,
          ).toJson(),
        ),
        subject: 'host:$id',
        status: OutboxStatus.pending.index,
        retries: 0,
        createdAt: DateTime(2026, 4, 17),
        updatedAt: DateTime(2026, 4, 17),
        priority: OutboxPriority.low.index,
      );
    }

    test(
      'bundles two pending items when flag is on and items fit under cap',
      () async {
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_test');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity1 = JournalEntity.journalEntry(
          meta: meta('e1'),
          entryText: const EntryText(plainText: 'Entry one'),
        );
        final entity2 = JournalEntity.journalEntry(
          meta: meta('e2'),
          entryText: const EntryText(plainText: 'Entry two'),
        );
        final jsonPath1 = relativeEntityPath(entity1);
        final jsonPath2 = relativeEntityPath(entity2);
        File('${tmp.path}$jsonPath1')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity1.toJson()));
        File('${tmp.path}$jsonPath2')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity2.toJson()));

        final item1 = pendingFor(id: 1, entryId: 'e1', jsonPath: jsonPath1);
        final item2 = pendingFor(id: 2, entryId: 'e2', jsonPath: jsonPath2);

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item1, item2]);
        when(() => repo.refreshItem(item1)).thenAnswer((_) async => item1);
        when(() => repo.refreshItem(item2)).thenAnswer((_) async => item2);
        when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        final capturedBundles = <Map<String, Uint8List>>[];
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((invocation) async {
          capturedBundles.add(
            invocation.namedArguments[#entries] as Map<String, Uint8List>,
          );
          return r'$bundle-id';
        });
        final capturedSkipSets = <Set<String>>[];
        when(
          () => sender.send(
            any(),
            skipAttachmentPaths: any<Set<String>>(
              named: 'skipAttachmentPaths',
            ),
          ),
        ).thenAnswer((invocation) async {
          capturedSkipSets.add(
            invocation.namedArguments[#skipAttachmentPaths] as Set<String>,
          );
          return true;
        });
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
        );

        final result = await proc.processQueue();

        // Bundle must have been uploaded once with both items' jsonPaths.
        expect(capturedBundles, hasLength(1));
        expect(
          capturedBundles.single.keys.toSet(),
          equals({jsonPath1, jsonPath2}),
        );
        // Both items' text events must have been sent with the skip set
        // containing both paths.
        expect(capturedSkipSets, hasLength(2));
        for (final s in capturedSkipSets) {
          expect(s, equals({jsonPath1, jsonPath2}));
        }
        verify(() => repo.markSent(item1)).called(1);
        verify(() => repo.markSent(item2)).called(1);
        verifyNever(() => repo.markRetry(any<OutboxItem>()));
        // Everything drained this tick → no more schedule.
        expect(result.shouldSchedule, isFalse);
      },
    );

    test(
      'falls through to head-only flow when flag is off',
      () async {
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_off');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('off-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));

        final item = pendingFor(
          id: 1,
          entryId: 'off-1',
          jsonPath: jsonPath,
        );
        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.refreshItem(item)).thenAnswer((_) async => item);
        when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => false);
        when(() => sender.send(any())).thenAnswer((_) async => true);
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
        );

        await proc.processQueue();

        // Bundle upload must NOT have happened.
        verifyNever(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        );
        // Regular send path ran for the head item.
        verify(() => sender.send(any())).called(1);
      },
    );

    test(
      'bundle upload failure marks bundled items for retry',
      () async {
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_fail');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('fail-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));

        final item = pendingFor(
          id: 1,
          entryId: 'fail-1',
          jsonPath: jsonPath,
        );
        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
          errorDelayOverride: const Duration(seconds: 1),
        );

        final result = await proc.processQueue();

        verify(() => repo.markRetry(item)).called(1);
        verifyNever(
          () => sender.send(
            any(),
            skipAttachmentPaths: any<Set<String>>(
              named: 'skipAttachmentPaths',
            ),
          ),
        );
        expect(result.shouldSchedule, isTrue);
        expect(result.nextDelay, const Duration(seconds: 1));
      },
    );

    test(
      'break on first non-bundleable item preserves head-first ordering',
      () async {
        // Head item has no attachments (e.g. SyncAiConfigDelete), so it is
        // non-bundleable. A later pending item DOES have attachments but must
        // not be bundled past the head — otherwise it would ship first and
        // violate ordering. Expect: return null → fall through to head-only.
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_order');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final noAttItem = OutboxItem(
          id: 1,
          message: jsonEncode(
            const SyncMessage.aiConfigDelete(id: 'cfg').toJson(),
          ),
          subject: 'host:1',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2026, 4, 17),
          updatedAt: DateTime(2026, 4, 17),
          priority: OutboxPriority.low.index,
        );
        final entity = JournalEntity.journalEntry(
          meta: meta('later'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));
        final laterItem = pendingFor(
          id: 2,
          entryId: 'later',
          jsonPath: jsonPath,
        );

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [noAttItem, laterItem]);
        when(
          () => repo.refreshItem(noAttItem),
        ).thenAnswer((_) async => noAttItem);
        when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(() => sender.send(any())).thenAnswer((_) async => true);
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
        );

        await proc.processQueue();

        // No bundle must have been uploaded — head-only path processed the
        // head (the no-attachment item) solo.
        verifyNever(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        );
        verify(() => sender.send(any())).called(1);
        verify(() => repo.markSent(noAttItem)).called(1);
        verifyNever(() => repo.markSent(laterItem));
      },
    );

    test(
      'bundled item send exception triggers retry and diagnostics',
      () async {
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_ex');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('ex-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));
        final item = pendingFor(id: 1, entryId: 'ex-1', jsonPath: jsonPath);

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.refreshItem(item)).thenAnswer((_) async => item);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((_) async => r'$bundle-ok');
        when(
          () => sender.send(
            any(),
            skipAttachmentPaths: any<Set<String>>(named: 'skipAttachmentPaths'),
          ),
        ).thenThrow(Exception('boom'));
        final loggedExceptionSubDomains = <String?>[];
        when(
          () => log.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((invocation) async {
          loggedExceptionSubDomains.add(
            invocation.namedArguments[#subDomain] as String?,
          );
        });
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
          retryDelayOverride: const Duration(seconds: 2),
        );

        final result = await proc.processQueue();

        verify(() => repo.markRetry(item)).called(1);
        expect(loggedExceptionSubDomains, contains('bundle.send'));
        expect(result.shouldSchedule, isTrue);
        expect(result.nextDelay, const Duration(seconds: 2));
      },
    );

    test(
      'retry cap on bundled item emits retryCapReached diagnostic',
      () async {
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_cap');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('cap-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));
        // One retry short of the cap — next attempt hits the diagnostic.
        final item = OutboxItem(
          id: 1,
          message: jsonEncode(
            SyncMessage.journalEntity(
              id: 'cap-1',
              jsonPath: jsonPath,
              vectorClock: null,
              status: SyncEntryStatus.initial,
            ).toJson(),
          ),
          subject: 'host:cap',
          status: OutboxStatus.pending.index,
          retries: 2,
          createdAt: DateTime(2026, 4, 17),
          updatedAt: DateTime(2026, 4, 17),
          priority: OutboxPriority.low.index,
        );

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.refreshItem(item)).thenAnswer((_) async => item);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((_) async => r'$bundle-ok');
        when(
          () => sender.send(
            any(),
            skipAttachmentPaths: any<Set<String>>(named: 'skipAttachmentPaths'),
          ),
        ).thenAnswer((_) async => false);
        final events = <String>[];
        when(
          () => log.captureEvent(
            captureAny<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((invocation) {
          events.add(invocation.positionalArguments.first.toString());
        });

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
          maxRetriesOverride: 3,
        );

        await proc.processQueue();

        verify(() => repo.markRetry(item)).called(1);
        expect(
          events.any(
            (e) =>
                e.contains('retryCapReached subject=host:cap attempts=3') &&
                e.contains('bundle'),
          ),
          isTrue,
          reason: 'expected retryCapReached event for bundled item at cap',
        );
      },
    );

    test(
      'invalid-JSON pending item is treated as non-bundleable',
      () async {
        // An item whose message is unparseable JSON: the decode inside the
        // enumeration loop throws, and the catch substitutes empty attachments
        // so the break-on-first-non-bundleable rule trips before any bundle
        // is built. The head-only path then handles the item.
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_dec');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final junk = OutboxItem(
          id: 1,
          message: '{ not-json',
          subject: 'host:junk',
          status: OutboxStatus.pending.index,
          retries: 0,
          createdAt: DateTime(2026, 4, 17),
          updatedAt: DateTime(2026, 4, 17),
          priority: OutboxPriority.low.index,
        );

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [junk]);
        when(() => repo.refreshItem(junk)).thenAnswer((_) async => junk);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
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

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
        );

        await proc.processQueue();

        verifyNever(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        );
        // Head-only path handled it via markRetry (decode would fail there
        // too and throw into the outer try/catch).
        verify(() => repo.markRetry(junk)).called(1);
      },
    );

    test(
      'missing JSON file during enumeration falls through to head-only',
      () async {
        // Enumerator returns empty for an item whose JSON file was deleted
        // before processQueue ran; bundled stays empty, _maybeProcessBundle
        // returns null, and the head-only path runs the item solo.
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_read');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('read-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        final jsonFile = File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));
        final item = pendingFor(id: 1, entryId: 'read-1', jsonPath: jsonPath);

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.refreshItem(item)).thenAnswer((_) async => item);
        when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((invocation) async {
          // Delete the file synchronously during pack — but the enumerator
          // already read bytes into the descriptor cache, so bundles built
          // from this message will still succeed. To force the read-failure
          // branch we must target a media file that the enumerator saw but
          // didn't cache. See below for a stricter test via stubbed sender.
          return r'$ok';
        });
        when(() => sender.send(any())).thenAnswer((_) async => true);
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

        // Delete the JSON file before the processor runs. The enumerator
        // will see it missing and return no descriptors, so bundled ends up
        // empty, _maybeProcessBundle returns null, and the head-only path
        // takes over.
        jsonFile.deleteSync();

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
        );

        await proc.processQueue();

        // No bundle upload — enumerator returned empty, so the item is
        // processed via the head-only path.
        verifyNever(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        );
        verify(() => sender.send(any())).called(1);
      },
    );

    test(
      'bundled item decode failure after refresh marks retry and continues',
      () async {
        // Enumeration sees a valid item. Refresh then returns an item whose
        // message is unparseable, simulating a concurrent write that
        // corrupted the stored payload. The per-item decode try/catch must
        // markRetry and continue, not propagate.
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_refr');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('refr-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));
        final item = pendingFor(id: 1, entryId: 'refr-1', jsonPath: jsonPath);
        final corrupted = OutboxItem(
          id: item.id,
          message: '{ not-json',
          subject: item.subject,
          status: item.status,
          retries: item.retries,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
          priority: item.priority,
        );

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.refreshItem(item)).thenAnswer((_) async => corrupted);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((_) async => r'$bundle-ok');
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});
        final exSubDomains = <String?>[];
        when(
          () => log.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((inv) async {
          exSubDomains.add(inv.namedArguments[#subDomain] as String?);
        });

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
        );

        await proc.processQueue();

        verify(() => repo.markRetry(corrupted)).called(1);
        expect(exSubDomains, contains('bundle.decode'));
        verifyNever(
          () => sender.send(
            any(),
            skipAttachmentPaths: any<Set<String>>(named: 'skipAttachmentPaths'),
          ),
        );
      },
    );

    test(
      'refresh returning null during bundle skips the item without error',
      () async {
        // Item was marked sent/deleted between fetch and the per-item loop.
        // refreshItem returns null; the loop must skip it cleanly with no
        // markSent or markRetry call.
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_rfn');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('rfn-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));
        final item = pendingFor(id: 1, entryId: 'rfn-1', jsonPath: jsonPath);

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.refreshItem(item)).thenAnswer((_) async => null);
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((_) async => r'$bundle-ok');
        when(
          () => log.captureEvent(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
        );

        final result = await proc.processQueue();

        verifyNever(() => repo.markRetry(any<OutboxItem>()));
        verifyNever(() => repo.markSent(any<OutboxItem>()));
        verifyNever(
          () => sender.send(
            any(),
            skipAttachmentPaths: any<Set<String>>(named: 'skipAttachmentPaths'),
          ),
        );
        expect(result.shouldSchedule, isFalse);
      },
    );

    test(
      'bundled item send timeout triggers retry with timedOut=true',
      () async {
        // The timeout callback path has its own bookkeeping (timedOut=true
        // logged alongside the subject diagnostic). A send() future that
        // never completes exercises it.
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_to');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('to-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));
        final item = pendingFor(id: 1, entryId: 'to-1', jsonPath: jsonPath);

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.refreshItem(item)).thenAnswer((_) async => item);
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((_) async => r'$bundle-ok');
        when(
          () => sender.send(
            any(),
            skipAttachmentPaths: any<Set<String>>(named: 'skipAttachmentPaths'),
          ),
        ).thenAnswer((_) => Completer<bool>().future);
        final events = <String>[];
        when(
          () => log.captureEvent(
            captureAny<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((inv) {
          events.add(inv.positionalArguments.first.toString());
        });

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
          sendTimeoutOverride: const Duration(milliseconds: 20),
        );

        await proc.processQueue();

        verify(() => repo.markRetry(item)).called(1);
        expect(
          events.any(
            (e) =>
                e.contains('bundle sendFailed subject=host:1') &&
                e.contains('timedOut=true'),
          ),
          isTrue,
          reason: 'expected the bundled-item timeout path to log timedOut=true',
        );
      },
    );

    test(
      'bundled item success resets repeated-subject diagnostic counters',
      () async {
        final tmp = Directory.systemTemp.createTempSync('outbox_bundle_reset');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();
        final db = MockJournalDb();

        final entity = JournalEntity.journalEntry(
          meta: meta('ok-1'),
          entryText: const EntryText(plainText: 'x'),
        );
        final jsonPath = relativeEntityPath(entity);
        File('${tmp.path}$jsonPath')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(entity.toJson()));
        final item = pendingFor(id: 1, entryId: 'ok-1', jsonPath: jsonPath);

        when(
          () => repo.fetchPending(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [item]);
        when(() => repo.refreshItem(item)).thenAnswer((_) async => item);
        when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
        when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
        when(
          () => db.getConfigFlag(useBundledAttachmentsFlag),
        ).thenAnswer((_) async => true);
        when(
          () => sender.sendAttachmentBundle(
            entries: any<Map<String, Uint8List>>(named: 'entries'),
          ),
        ).thenAnswer((_) async => r'$bundle-ok');
        var sendResult = false;
        when(
          () => sender.send(
            any(),
            skipAttachmentPaths: any<Set<String>>(named: 'skipAttachmentPaths'),
          ),
        ).thenAnswer((_) async => sendResult);
        final events = <String>[];
        when(
          () => log.captureEvent(
            captureAny<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((inv) {
          events.add(inv.positionalArguments.first.toString());
        });

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          journalDb: db,
          documentsDirectory: tmp,
        );

        // Tick 1: fail to seed _lastFailedSubject/_lastFailedRepeats=1.
        await proc.processQueue();
        verify(() => repo.markRetry(item)).called(1);
        expect(
          events.any(
            (e) =>
                e.contains('bundle sendFailed subject=host:1') &&
                e.contains('repeats=1'),
          ),
          isTrue,
        );
        events.clear();

        // Tick 2: succeed → the success branch must reset the tracker.
        sendResult = true;
        final tick2 = await proc.processQueue();
        verify(() => repo.markSent(item)).called(1);
        expect(tick2.shouldSchedule, isFalse);
        events.clear();

        // Tick 3: fail again for the same subject. If the Tick 2 success
        // reset the tracker, the repeats count restarts at 1. Without the
        // reset it would already be 2 on the first failure after success.
        sendResult = false;
        await proc.processQueue();
        expect(
          events.any(
            (e) =>
                e.contains('bundle sendFailed subject=host:1') &&
                e.contains('repeats=1'),
          ),
          isTrue,
          reason:
              'expected the repeat counter to restart at 1 after the Tick 2 '
              'success — otherwise the reset branch on the success path is '
              'not exercised.',
        );
        expect(
          events.any((e) => e.contains('repeats=2')),
          isFalse,
          reason:
              'counter should NOT be 2: Tick 2 success must have cleared it.',
        );
      },
    );
  });
}
