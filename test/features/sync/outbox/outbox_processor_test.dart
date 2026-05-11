import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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
  String? rawMessage,
  DateTime? updatedAt,
}) {
  return OutboxItem(
    id: id,
    message:
        rawMessage ??
        jsonEncode(SyncMessage.aiConfigDelete(id: messageId).toJson()),
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
    () => repo.claimNextBatch(
      maxSize: any(named: 'maxSize'),
      leaseDuration: any(named: 'leaseDuration'),
    ),
  ).thenAnswer((_) async {
    if (call >= items.length) return <OutboxItem>[];
    final next = items[call++];
    return next == null ? <OutboxItem>[] : [next];
  });
}

void _stubHasMorePending(MockOutboxRepository repo, {bool hasMore = false}) {
  when(() => repo.hasMorePending()).thenAnswer((_) async => hasMore);
}

const _generatedProcessorRetryDelay = Duration(milliseconds: 75);
const _generatedProcessorErrorDelay = Duration(milliseconds: 225);
const _generatedProcessorMaxRetries = 3;

enum _GeneratedProcessorPayloadShape {
  valid,
  headInvalid,
  tailInvalid,
}

enum _GeneratedProcessorSendOutcome {
  success,
  softFailure,
  exception,
}

enum _GeneratedProcessorRetryProfile {
  belowCap,
  headAtCap,
  tailAtCap,
}

enum _GeneratedProcessorPostSendObservation {
  ok,
  hasMoreThrows,
  captureEventThrows,
}

class _GeneratedProcessorScenario {
  const _GeneratedProcessorScenario({
    required this.rowCount,
    required this.payloadShape,
    required this.sendOutcome,
    required this.hasMoreAfterSuccess,
    required this.retryProfile,
    required this.postSendObservation,
  });

  final int rowCount;
  final _GeneratedProcessorPayloadShape payloadShape;
  final _GeneratedProcessorSendOutcome sendOutcome;
  final bool hasMoreAfterSuccess;
  final _GeneratedProcessorRetryProfile retryProfile;
  final _GeneratedProcessorPostSendObservation postSendObservation;

  int get claimedCount => rowCount;

  bool get hasClaim => claimedCount > 0;

  bool get usesBundleCommit => claimedCount > 1;

  bool get decodeFails {
    if (!hasClaim) {
      return false;
    }
    return switch (payloadShape) {
      _GeneratedProcessorPayloadShape.valid => false,
      _GeneratedProcessorPayloadShape.headInvalid => true,
      _GeneratedProcessorPayloadShape.tailInvalid => usesBundleCommit,
    };
  }

  bool get sendsMessage => hasClaim && !decodeFails;

  bool get sendSucceeds =>
      sendsMessage && sendOutcome == _GeneratedProcessorSendOutcome.success;

  bool get failsAfterClaim => hasClaim && !sendSucceeds;

  bool get postSendFails =>
      sendSucceeds &&
      postSendObservation != _GeneratedProcessorPostSendObservation.ok;

  bool get capReachedOnFailure {
    if (!failsAfterClaim) {
      return false;
    }
    if (usesBundleCommit) {
      for (var index = 0; index < claimedCount; index++) {
        if (retriesForIndex(index) + 1 >= _generatedProcessorMaxRetries) {
          return true;
        }
      }
      return false;
    }
    return retriesForIndex(0) + 1 >= _generatedProcessorMaxRetries;
  }

  Duration? get expectedDelay {
    if (!hasClaim) {
      return null;
    }
    if (sendSucceeds) {
      if (postSendFails || hasMoreAfterSuccess) {
        return Duration.zero;
      }
      return null;
    }
    if (capReachedOnFailure) {
      return Duration.zero;
    }
    return sendsMessage &&
            sendOutcome == _GeneratedProcessorSendOutcome.softFailure
        ? _generatedProcessorRetryDelay
        : _generatedProcessorErrorDelay;
  }

  int retriesForIndex(int index) {
    return switch (retryProfile) {
      _GeneratedProcessorRetryProfile.belowCap => 0,
      _GeneratedProcessorRetryProfile.headAtCap => index == 0 ? 2 : 0,
      _GeneratedProcessorRetryProfile.tailAtCap =>
        usesBundleCommit && index == claimedCount - 1 ? 2 : 0,
    };
  }

  List<OutboxItem> claimedRows() {
    return [
      for (var index = 0; index < claimedCount; index++)
        _item(
          id: index + 1,
          subject: 'generated:${index + 1}',
          retries: retriesForIndex(index),
          messageId: 'generated-${index + 1}',
          rawMessage: _messageForIndex(index),
        ),
    ];
  }

  String? _messageForIndex(int index) {
    if (payloadShape == _GeneratedProcessorPayloadShape.headInvalid &&
        index == 0) {
      return '{not-json';
    }
    if (payloadShape == _GeneratedProcessorPayloadShape.tailInvalid &&
        usesBundleCommit &&
        index == claimedCount - 1) {
      return '{not-json';
    }
    return null;
  }

  @override
  String toString() {
    return '_GeneratedProcessorScenario('
        'rowCount: $rowCount, '
        'payloadShape: $payloadShape, '
        'sendOutcome: $sendOutcome, '
        'hasMoreAfterSuccess: $hasMoreAfterSuccess, '
        'retryProfile: $retryProfile, '
        'postSendObservation: $postSendObservation'
        ')';
  }
}

extension _AnyGeneratedProcessorScenario on glados.Any {
  glados.Generator<_GeneratedProcessorPayloadShape> get processorPayloadShape =>
      glados.AnyUtils(this).choose(_GeneratedProcessorPayloadShape.values);

  glados.Generator<_GeneratedProcessorSendOutcome> get processorSendOutcome =>
      glados.AnyUtils(this).choose(_GeneratedProcessorSendOutcome.values);

  glados.Generator<_GeneratedProcessorRetryProfile> get processorRetryProfile =>
      glados.AnyUtils(this).choose(_GeneratedProcessorRetryProfile.values);

  glados.Generator<_GeneratedProcessorPostSendObservation>
  get processorPostSendObservation => glados.AnyUtils(
    this,
  ).choose(_GeneratedProcessorPostSendObservation.values);

  glados.Generator<_GeneratedProcessorScenario> get processorScenario =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 5),
        processorPayloadShape,
        processorSendOutcome,
        glados.BoolAny(this).bool,
        processorRetryProfile,
        processorPostSendObservation,
        (
          int rowCount,
          _GeneratedProcessorPayloadShape payloadShape,
          _GeneratedProcessorSendOutcome sendOutcome,
          bool hasMoreAfterSuccess,
          _GeneratedProcessorRetryProfile retryProfile,
          _GeneratedProcessorPostSendObservation postSendObservation,
        ) => _GeneratedProcessorScenario(
          rowCount: rowCount,
          payloadShape: payloadShape,
          sendOutcome: sendOutcome,
          hasMoreAfterSuccess: hasMoreAfterSuccess,
          retryProfile: retryProfile,
          postSendObservation: postSendObservation,
        ),
      );
}

void _stubGeneratedClaim({
  required MockOutboxRepository repo,
  required List<OutboxItem> claimedRows,
}) {
  when(
    () => repo.claimNextBatch(
      maxSize: any(named: 'maxSize'),
      leaseDuration: any(named: 'leaseDuration'),
    ),
  ).thenAnswer((_) async => claimedRows);
}

void _stubGeneratedRepositoryMutations(MockOutboxRepository repo) {
  when(() => repo.markSent(any<OutboxItem>())).thenAnswer((_) async {});
  when(() => repo.markSentBatch(any())).thenAnswer((_) async {});
  when(() => repo.markRetry(any<OutboxItem>())).thenAnswer((_) async {});
  when(() => repo.markRetryBatch(any())).thenAnswer((_) async {});
}

void _stubGeneratedHasMore({
  required MockOutboxRepository repo,
  required _GeneratedProcessorScenario scenario,
}) {
  if (scenario.postSendObservation ==
      _GeneratedProcessorPostSendObservation.hasMoreThrows) {
    when(() => repo.hasMorePending()).thenThrow(StateError('hasMore failed'));
  } else {
    when(
      () => repo.hasMorePending(),
    ).thenAnswer((_) async => scenario.hasMoreAfterSuccess);
  }
}

void _stubGeneratedLogging({
  required MockLoggingService log,
  required _GeneratedProcessorScenario scenario,
}) {
  when(
    () => log.captureException(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
      stackTrace: any<StackTrace?>(named: 'stackTrace'),
    ),
  ).thenAnswer((_) async {});

  final eventStub = when(
    () => log.captureEvent(
      any<Object>(),
      domain: any<String>(named: 'domain'),
      subDomain: any<String>(named: 'subDomain'),
    ),
  );
  if (scenario.postSendObservation ==
      _GeneratedProcessorPostSendObservation.captureEventThrows) {
    eventStub.thenThrow(StateError('captureEvent failed'));
  } else {
    eventStub.thenAnswer((_) {});
  }
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
      () => repo.claimNextBatch(
        maxSize: any(named: 'maxSize'),
        leaseDuration: any(named: 'leaseDuration'),
      ),
    ).thenAnswer((_) async => <OutboxItem>[]);
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

  glados.Glados(
    glados.any.processorScenario,
    glados.ExploreConfig(numRuns: 220),
  ).test(
    'generated processQueue scenarios match the bundle state model',
    (scenario) async {
      final repo = MockOutboxRepository();
      final sender = MockMessageSender();
      final log = MockLoggingService();
      final claimedRows = scenario.claimedRows();
      final sentMessages = <SyncMessage>[];

      _stubGeneratedClaim(repo: repo, claimedRows: claimedRows);
      _stubGeneratedRepositoryMutations(repo);
      _stubGeneratedHasMore(repo: repo, scenario: scenario);
      _stubGeneratedLogging(log: log, scenario: scenario);

      when(() => sender.send(any())).thenAnswer((invocation) async {
        final message = invocation.positionalArguments.single as SyncMessage;
        sentMessages.add(message);
        return switch (scenario.sendOutcome) {
          _GeneratedProcessorSendOutcome.success => true,
          _GeneratedProcessorSendOutcome.softFailure => false,
          _GeneratedProcessorSendOutcome.exception => throw StateError(
            'generated send failure',
          ),
        };
      });

      final processor = OutboxProcessor(
        repository: repo,
        messageSender: sender,
        loggingService: log,
        retryDelayOverride: _generatedProcessorRetryDelay,
        errorDelayOverride: _generatedProcessorErrorDelay,
        maxRetriesOverride: _generatedProcessorMaxRetries,
      );

      final result = await processor.processQueue();

      expect(result.nextDelay, scenario.expectedDelay);
      expect(result.shouldSchedule, scenario.expectedDelay != null);

      verify(
        () => repo.claimNextBatch(
          maxSize: any(named: 'maxSize'),
          leaseDuration: any(named: 'leaseDuration'),
        ),
      ).called(1);
      verifyNever(
        () => repo.claim(leaseDuration: any(named: 'leaseDuration')),
      );

      if (scenario.sendsMessage) {
        expect(sentMessages, hasLength(1));
        final sent = sentMessages.single;
        if (scenario.usesBundleCommit) {
          final bundle = sent as SyncOutboxBundle;
          expect(bundle.children, hasLength(scenario.claimedCount));
          expect(
            bundle.children,
            everyElement(isA<SyncAiConfigDelete>()),
          );
        } else {
          expect(
            sent,
            isA<SyncAiConfigDelete>().having(
              (message) => message.id,
              'id',
              'generated-1',
            ),
          );
        }
      } else {
        expect(sentMessages, isEmpty);
      }

      if (!scenario.hasClaim) {
        verifyNever(() => repo.markSent(any()));
        verifyNever(() => repo.markSentBatch(any()));
        verifyNever(() => repo.markRetry(any()));
        verifyNever(() => repo.markRetryBatch(any()));
      } else if (scenario.sendSucceeds) {
        if (scenario.usesBundleCommit) {
          final captured =
              verify(
                    () => repo.markSentBatch(captureAny()),
                  ).captured.single
                  as List<OutboxItem>;
          expect(
            captured.map((row) => row.id),
            claimedRows.map((row) => row.id),
          );
          verifyNever(() => repo.markSent(any()));
        } else {
          verify(() => repo.markSent(claimedRows.single)).called(1);
          verifyNever(() => repo.markSentBatch(any()));
        }
        verifyNever(() => repo.markRetry(any()));
        verifyNever(() => repo.markRetryBatch(any()));
      } else if (scenario.usesBundleCommit) {
        final captured =
            verify(
                  () => repo.markRetryBatch(captureAny()),
                ).captured.single
                as List<OutboxItem>;
        expect(
          captured.map((row) => row.id),
          claimedRows.map((row) => row.id),
        );
        verifyNever(() => repo.markRetry(any()));
        verifyNever(() => repo.markSent(any()));
        verifyNever(() => repo.markSentBatch(any()));
      } else {
        verify(() => repo.markRetry(claimedRows.single)).called(1);
        verifyNever(() => repo.markRetryBatch(any()));
        verifyNever(() => repo.markSent(any()));
        verifyNever(() => repo.markSentBatch(any()));
      }
    },
    tags: 'glados',
  );

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
      () => repo.claimNextBatch(
        maxSize: any(named: 'maxSize'),
        leaseDuration: any(named: 'leaseDuration'),
      ),
    ).thenAnswer((_) async => [item]);
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
        () => repo.claimNextBatch(
          maxSize: any(named: 'maxSize'),
          leaseDuration: any(named: 'leaseDuration'),
        ),
      ).thenAnswer((_) async {
        call++;
        return [
          if (call == 1)
            s0
          else
            call == 2
                ? s1
                : call == 3
                ? s2
                : s0, // 4th call after reset
        ];
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
      'the wire pattern is bundle(50) → bundle(49) → image alone → '
      'bundle(50) × 8 — 500 rows ship in 11 sends instead of 500',
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
      'a bundle send raising an exception (not a soft false return) routes '
      'through markRetryBatch on the catch path and schedules the standard '
      'errorDelay backoff — proves bundle exception handling stays out of '
      'the markedSent fast-path',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = [
          for (var i = 1; i <= 3; i++) textItem(id: i),
        ];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markRetryBatch(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenThrow(StateError('transport boom'));
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          errorDelayOverride: const Duration(milliseconds: 444),
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
        expect(result.nextDelay, const Duration(milliseconds: 444));
      },
    );

    test(
      'bundle exception path also honors the retry-cap fast-path: when any '
      'row in the batch is one retry away from the cap, an exception '
      'still routes to delay=0 instead of the standard errorDelay',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        final queue = [
          textItem(id: 1).copyWith(retries: 1), // hits cap on next retry
          textItem(id: 2),
        ];
        stubBatchClaimFromQueue(repo, queue);
        when(() => repo.markRetryBatch(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenThrow(StateError('transport boom'));
        _stubSilentLogging(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
          maxRetriesOverride: 2,
          errorDelayOverride: const Duration(seconds: 30),
        );

        final result = await proc.processQueue();

        expect(result.shouldSchedule, isTrue);
        expect(result.nextDelay, Duration.zero);
        verify(() => repo.markRetryBatch(any())).called(1);
      },
    );

    test(
      'repeated bundle failures on the same head subject increment the '
      'repeat counter — head-of-queue diagnostics keep tracking the stuck '
      'subject across retries, exactly as for single-row failures',
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        // Same head row across both calls. We rebuild the queue each time
        // because stubBatchClaimFromQueue empties it as it claims.
        when(() => repo.markRetryBatch(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);
        final events = _captureEvents(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
        );

        // First failed bundle.
        stubBatchClaimFromQueue(repo, [textItem(id: 1), textItem(id: 2)]);
        await proc.processQueue();
        // Second failed bundle with the same head subject.
        stubBatchClaimFromQueue(repo, [textItem(id: 1), textItem(id: 2)]);
        await proc.processQueue();

        // The second log line carries repeats=2.
        expect(
          events.any((e) => e.contains('repeats=2')),
          isTrue,
          reason: 'expected the head-subject repeat counter to increment',
        );
      },
    );

    test(
      'a successful bundle send after a prior failure on the same head '
      'subject clears the repeat tracker — so the next stuck subject '
      "doesn't inherit a stale repeat count from a different bundle",
      () async {
        final repo = MockOutboxRepository();
        final sender = MockMessageSender();
        final log = MockLoggingService();

        when(() => repo.markRetryBatch(any())).thenAnswer((_) async {});
        when(() => repo.markSentBatch(any())).thenAnswer((_) async {});
        // First call fails, second succeeds.
        var calls = 0;
        when(() => sender.send(any())).thenAnswer((_) async {
          calls++;
          return calls > 1;
        });
        final events = _captureEvents(log);

        final proc = OutboxProcessor(
          repository: repo,
          messageSender: sender,
          loggingService: log,
        );

        stubBatchClaimFromQueue(repo, [textItem(id: 1), textItem(id: 2)]);
        await proc.processQueue();
        stubBatchClaimFromQueue(repo, [textItem(id: 1), textItem(id: 2)]);
        await proc.processQueue();

        // After success, the next bundle on a different subject must start
        // fresh: simulate a new failing bundle with a different head. Re-
        // stub `sender.send` so this third pass actually fails — without
        // this the running counter rolls over and the assertion would pass
        // vacuously even on a regression.
        stubBatchClaimFromQueue(repo, [
          textItem(id: 99, subject: 'host:other'),
        ]);
        when(() => repo.markRetry(any())).thenAnswer((_) async {});
        when(() => sender.send(any())).thenAnswer((_) async => false);
        await proc.processQueue();

        // The single-row failure log for host:other should carry repeats=1
        // (the success in between cleared the prior counter).
        final otherFails = events
            .where((e) => e.contains('host:other'))
            .toList();
        expect(otherFails, isNotEmpty);
        expect(
          otherFails.last.contains('repeats=1'),
          isTrue,
          reason: 'tracker should reset after the successful bundle',
        );
      },
    );
  });
}
