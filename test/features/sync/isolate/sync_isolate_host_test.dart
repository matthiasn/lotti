import 'dart:async';
import 'dart:isolate';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_worker.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// Fake workers. Each runs in a real spawned isolate, so they are top-level
// and keep no state the test could share with them.

/// Shakes hands, then exits on the first request it receives.
void _exitOnRequest(SyncIsolateBoot boot) {
  final commands = ReceivePort();
  boot.host.send(SyncIsolateReady(commands.sendPort));
  commands.listen((_) => Isolate.exit());
}

/// Shakes hands, then throws out of its handler on the first request.
void _throwOnRequest(SyncIsolateBoot boot) {
  final commands = ReceivePort();
  boot.host.send(SyncIsolateReady(commands.sendPort));
  commands.listen((_) => throw StateError('worker blew up'));
}

/// Shakes hands and never answers anything — not even shutdown.
void _neverAnswers(SyncIsolateBoot boot) {
  final commands = ReceivePort();
  boot.host.send(SyncIsolateReady(commands.sendPort));
  commands.listen((_) {});
}

/// Exits without ever shaking hands.
void _exitsBeforeHandshake(SyncIsolateBoot boot) => Isolate.exit();

/// Stays alive without ever shaking hands.
void _neverShakesHands(SyncIsolateBoot boot) => ReceivePort().listen((_) {});

/// Plays the queue's owner: leases two canned entries, settles with the
/// count it was given, and reports the tables it wrote and a line of log.
void _ownsTheQueue(SyncIsolateBoot boot) {
  final commands = ReceivePort();
  boot.host.send(SyncIsolateReady(commands.sendPort));
  commands.listen((message) {
    final request = message as SyncIsolateRequest;
    switch (request.command) {
      case SyncIsolateLeaseEntries(:final maxBatch):
        boot.host.send(
          SyncIsolateReply.success(request.requestId, [
            for (var i = 0; i < maxBatch && i < 2; i++)
              InboundQueueEntry(
                queueId: i,
                eventId: '\$e$i',
                roomId: '!room:example.org',
                originTs: i,
                enqueuedAt: i,
                attempts: 0,
                rawJson: '{}',
              ),
          ]),
        );
      case SyncIsolateSettleEntries(:final outcomes):
        boot.host
          ..send(
            SyncIsolateLog(
              'settled ${outcomes.length}',
              subDomain: 'queue',
              level: InsightLevel.warn,
            ),
          )
          ..send(const SyncIsolateTablesChanged(['inbound_event_queue']))
          ..send(
            SyncIsolateReply.success(
              request.requestId,
              outcomes.where((o) => o.outcome == ApplyOutcome.applied).length,
            ),
          );
      case SyncIsolateShutdown():
        boot.host.send(SyncIsolateReply.success(request.requestId, null));
        commands.close();
      default:
        throw StateError('not in this test');
    }
  });
}

/// Shakes hands, asks the host one settings question and reports the answer
/// — or the failure — as a log line, then idles. Sends every event type the
/// stack would, once, on a `ping`.
void _asksTheHost(SyncIsolateBoot boot) {
  final commands = ReceivePort();
  boot.host
    ..send(SyncIsolateReady(commands.sendPort))
    ..send(
      const SyncIsolateHostRequest(
        requestId: 41,
        query: SyncIsolateHostSettingsGet('room'),
      ),
    );
  commands.listen((message) {
    switch (message) {
      case SyncIsolateHostReply(
        :final requestId,
        :final result,
        :final failure,
      ):
        boot.host.send(
          SyncIsolateLog(
            'reply $requestId result=$result failure=${failure?.message}',
            subDomain: 'asked',
          ),
        );
      case SyncIsolateRequest(:final requestId, :final command):
        if (command is SyncIsolatePing) {
          boot.host
            ..send(const SyncIsolateRoomIdChanged('!room:example.org'))
            ..send(const SyncIsolateStackChanged(ready: true))
            ..send(
              SyncIsolateReply.success(
                requestId,
                const SyncIsolateHealth(uptime: Duration.zero, handled: 1),
              ),
            );
        } else if (command is SyncIsolateGetRoom) {
          boot.host.send(
            SyncIsolateReply.success(requestId, '!room:example.org'),
          );
        } else if (command is SyncIsolateShutdown) {
          boot.host.send(SyncIsolateReply.success(requestId, null));
          commands.close();
        }
    }
  });
}

/// Answers settings reads with a fixed value and refuses everything else.
class _FakeHostServices extends Fake implements SyncIsolateHostServices {
  @override
  Future<String?> settingsGet(String key) async => '$key-value';

  @override
  Future<int> settingsSet(String key, String value) async =>
      throw StateError('read-only');
}

/// Answers every question the worker's stack can ask, each recognisably.
class _AnswersEverything implements SyncIsolateHostServices {
  @override
  Future<String?> settingsGet(String key) async => '$key-value';

  @override
  Future<int> settingsSet(String key, String value) async => 1;

  @override
  Future<void> settingsRemove(String key) async {}

  @override
  Future<Map<String, JournalEntity>> journalEntities(
    List<String> ids,
  ) async => {};

  @override
  Future<JournalEntity?> openConflictVersion(
    String id,
    VectorClock vectorClock,
  ) async => null;

  @override
  Future<bool> configFlag(String flagName) async => flagName == 'on';

  @override
  Future<String?> vectorClockHost() async => 'host-1';

  @override
  Future<bool> localVcDominates(
    String relativePath,
    VectorClock? incomingVectorClock,
  ) async => incomingVectorClock == null;
}

/// Shakes hands, asks the host one of everything, and logs each answer.
void _asksEverything(SyncIsolateBoot boot) {
  final commands = ReceivePort();
  boot.host.send(SyncIsolateReady(commands.sendPort));
  const queries = <SyncIsolateHostQuery>[
    SyncIsolateHostSettingsGet('room'),
    SyncIsolateHostSettingsSet('room', '!r'),
    SyncIsolateHostSettingsRemove('room'),
    SyncIsolateHostJournalEntities(['a', 'b']),
    SyncIsolateHostOpenConflictVersion(
      id: 'a',
      vectorClock: VectorClock({'h': 1}),
    ),
    SyncIsolateHostConfigFlag('on'),
    SyncIsolateHostVectorClockHost(),
    SyncIsolateHostLocalVcDominates(
      relativePath: '/images/a.jpg',
      incomingVectorClock: null,
    ),
  ];
  for (var i = 0; i < queries.length; i++) {
    boot.host.send(
      SyncIsolateHostRequest(requestId: i + 1, query: queries[i]),
    );
  }
  commands.listen((message) {
    if (message is SyncIsolateHostReply) {
      boot.host.send(
        SyncIsolateLog(
          'reply ${message.requestId} result=${message.result} '
          'failure=${message.failure?.message}',
          subDomain: 'asked',
        ),
      );
    } else if (message is SyncIsolateRequest &&
        message.command is SyncIsolateShutdown) {
      commands.close();
    }
  });
}

/// Shakes hands and then idles.
void _idles(SyncIsolateBoot boot) {
  final commands = ReceivePort();
  boot.host.send(SyncIsolateReady(commands.sendPort));
  commands.listen((_) {});
}

/// Answers every request with a failure of its own, and exits on shutdown
/// as a well-behaved worker does.
void _rejectsEverything(SyncIsolateBoot boot) {
  final commands = ReceivePort();
  boot.host.send(SyncIsolateReady(commands.sendPort));
  commands.listen((message) {
    final request = message as SyncIsolateRequest;
    boot.host.send(
      SyncIsolateReply.failure(
        request.requestId,
        const SyncIsolateFailure(SyncIsolateErrorCode.failed, 'nope'),
      ),
    );
    if (request.command is SyncIsolateShutdown) commands.close();
  });
}

/// A worker's configuration for tests: an in-memory `sync.sqlite`, so no
/// directory is needed.
const inMemoryConfig = SyncIsolateConfig(
  documentsPath: '',
  temporaryPath: '',
  inMemoryDatabase: true,
);

Matcher _failsWith(SyncIsolateErrorCode code) => throwsA(
  isA<SyncIsolateFailure>().having((f) => f.code, 'code', code),
);

/// Stands in for the host's respawn timers: records the backoff each respawn
/// was given and fires one only when the test says so, so supervision runs
/// on the test's schedule instead of a real timer's.
class _ManualTimers {
  final delays = <Duration>[];
  final _pending = <_ManualTimer>[];

  Timer call(Duration delay, void Function() callback) {
    delays.add(delay);
    final timer = _ManualTimer(callback);
    _pending.add(timer);
    return timer;
  }

  /// Fires the most recently scheduled respawn.
  void fireLast() => _pending.removeLast().fire();

  bool get lastCancelled => _pending.last.cancelled;
}

class _ManualTimer implements Timer {
  _ManualTimer(this._callback);

  final void Function() _callback;
  bool cancelled = false;
  var _fired = false;

  void fire() {
    if (cancelled || _fired) return;
    _fired = true;
    _callback();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !_fired;

  @override
  int get tick => _fired ? 1 : 0;
}

void main() {
  late MockDomainLogger logger;
  late _ManualTimers timers;
  final hosts = <SyncIsolateHost>[];

  SyncIsolateHost makeHost({
    SyncIsolateEntry entry = syncIsolateEntry,
    Duration requestTimeout = const Duration(seconds: 30),
    Duration startTimeout = const Duration(seconds: 30),
    List<Duration> respawnBackoff = const [Duration(seconds: 1)],
    Duration stableUptime = const Duration(hours: 1),
    SyncIsolateHostServices? services,
  }) {
    final host = SyncIsolateHost(
      logger: logger,
      config: inMemoryConfig,
      services: services,
      entry: entry,
      requestTimeout: requestTimeout,
      startTimeout: startTimeout,
      respawnBackoff: respawnBackoff,
      stableUptime: stableUptime,
      createTimer: timers.call,
    );
    hosts.add(host);
    return host;
  }

  /// Completes with the next time [host] reaches [state].
  Future<void> reaches(SyncIsolateHost host, SyncIsolateState state) =>
      host.states.firstWhere((s) => s == state);

  /// Starts [host] and waits until its worker has shaken hands.
  Future<void> startRunning(SyncIsolateHost host) async {
    final running = reaches(host, SyncIsolateState.running);
    host.start();
    await running;
  }

  /// Sends a ping the worker exits on, and waits for the host to schedule
  /// the respawn.
  Future<void> crash(SyncIsolateHost host) async {
    final restarting = reaches(host, SyncIsolateState.restarting);
    await expectLater(
      host.ping(),
      _failsWith(SyncIsolateErrorCode.isolateExited),
    );
    await restarting;
  }

  /// Fires the pending respawn and waits for the new worker's handshake.
  Future<void> respawn(SyncIsolateHost host) async {
    final running = reaches(host, SyncIsolateState.running);
    timers.fireLast();
    await running;
  }

  setUp(() {
    timers = _ManualTimers();
    logger = MockDomainLogger();
    when(
      () => logger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    when(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    ).thenReturn(null);
  });

  tearDown(() async {
    for (final host in hosts) {
      await host.dispose();
    }
    hosts.clear();
  });

  group('with the production worker', () {
    test(
      'starts, answers pings in order, and counts what it handled',
      () async {
        final host = makeHost();
        final seen = <SyncIsolateState>[];
        host.states.listen(seen.add);

        await startRunning(host);
        final first = await host.ping();
        final second = await host.ping();

        expect(seen, [SyncIsolateState.starting, SyncIsolateState.running]);
        expect(first.handled, 1);
        expect(second.handled, 2);
        expect(second.uptime, greaterThanOrEqualTo(first.uptime));
      },
    );

    test("forwards the worker's log lines to the sync log", () async {
      final host = makeHost();
      await startRunning(host);
      // The ping's reply is sent after the startup line, and one port keeps
      // its order, so by the time it lands the line has been written.
      await host.ping();

      verify(
        () => logger.log(
          LogDomain.sync,
          'sync isolate started',
          subDomain: 'isolate',
          level: any(named: 'level'),
        ),
      ).called(1);
    });

    test(
      'dispose shuts the worker down politely and refuses later calls',
      () async {
        final host = makeHost();
        await startRunning(host);

        await host.dispose();

        expect(host.state, SyncIsolateState.disposed);
        await expectLater(
          host.ping(),
          _failsWith(SyncIsolateErrorCode.notRunning),
        );
        // The worker exited on its own, so nothing was crash-logged.
        verifyNever(
          () => logger.error(
            any(),
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
            message: any(named: 'message'),
          ),
        );
      },
    );
  });

  test('a request before start fails at once rather than waiting', () async {
    final host = makeHost();

    await expectLater(host.ping(), _failsWith(SyncIsolateErrorCode.notRunning));
  });

  test('start twice is a programming error', () async {
    final host = makeHost();
    await startRunning(host);

    expect(host.start, throwsStateError);
  });

  test("a worker's own failure reply reaches the caller unchanged", () async {
    final host = makeHost(entry: _rejectsEverything);
    await startRunning(host);

    await expectLater(
      host.ping(),
      _failsWith(SyncIsolateErrorCode.failed),
    );
    expect(host.state, SyncIsolateState.running);
  });

  test('an unanswered request fails with a timeout', () async {
    final host = makeHost(entry: _neverAnswers, requestTimeout: Duration.zero);
    await startRunning(host);

    await expectLater(host.ping(), _failsWith(SyncIsolateErrorCode.timeout));
    expect(host.state, SyncIsolateState.running);
  });

  test('a worker that never exits on shutdown is killed by dispose', () async {
    final host = makeHost(entry: _neverAnswers, requestTimeout: Duration.zero);
    await startRunning(host);

    await host.dispose();

    expect(host.state, SyncIsolateState.disposed);
  });

  test('a worker that cannot start is logged and retried, never thrown into '
      'the caller', () async {
    final host = makeHost(entry: _exitsBeforeHandshake);
    final restarting = reaches(host, SyncIsolateState.restarting);

    host.start();
    await restarting;

    verify(
      () => logger.error(
        LogDomain.sync,
        any<Object>(
          that: isA<SyncIsolateFailure>().having(
            (f) => f.code,
            'code',
            SyncIsolateErrorCode.isolateExited,
          ),
        ),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'isolate',
        message: 'starting the sync isolate failed',
      ),
    ).called(1);
    await expectLater(
      host.ping(),
      _failsWith(SyncIsolateErrorCode.notRunning),
    );
  });

  test('a worker that never shakes hands times out its start, is logged '
      'with the reason, and is retried', () async {
    final host = makeHost(
      entry: _neverShakesHands,
      startTimeout: Duration.zero,
    );
    final restarting = reaches(host, SyncIsolateState.restarting);

    host.start();
    await restarting;

    final logged = verify(
      () => logger.error(
        LogDomain.sync,
        captureAny(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'isolate',
        message: 'starting the sync isolate failed',
      ),
    ).captured.single;
    // What lands in the log names the code and the budget it ran out of.
    expect(
      '$logged',
      'SyncIsolateFailure(timeout): no handshake from the sync isolate after '
          '${Duration.zero}',
    );
  });

  test(
    'a worker that shakes hands after dispose is killed, not adopted',
    () async {
      final host = makeHost(entry: _idles)..start();
      await host.dispose();

      await untilCalled(
        () => logger.log(
          LogDomain.sync,
          'sync isolate finished starting after dispose; killed it',
          subDomain: 'isolate',
          level: any(named: 'level'),
        ),
      );

      expect(host.state, SyncIsolateState.disposed);
      verifyNever(
        () => logger.log(
          any(),
          any(that: startsWith('sync isolate handshake')),
          subDomain: any(named: 'subDomain'),
          level: any(named: 'level'),
        ),
      );
    },
  );

  group('supervision', () {
    test(
      'a worker that exits fails the request it held and is respawned',
      () async {
        final host = makeHost(entry: _exitOnRequest);
        await startRunning(host);

        await crash(host);
        await respawn(host);

        // A fresh worker received this request — and exited on it in turn.
        await expectLater(
          host.ping(),
          _failsWith(SyncIsolateErrorCode.isolateExited),
        );
        verify(
          () => logger.error(
            LogDomain.sync,
            any<Object>(that: startsWith('sync isolate exited unexpectedly')),
            subDomain: 'isolate',
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test('an uncaught error in the worker is logged with its trace, ahead of '
        'the exit it causes', () async {
      final host = makeHost(entry: _throwOnRequest);
      await startRunning(host);

      await crash(host);

      // Both arrive on one port, so the trace is never lost to an exit that
      // overtook it.
      verifyInOrder([
        () => logger.error(
          LogDomain.sync,
          any<Object>(that: contains('worker blew up')),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'isolate',
          message: 'uncaught error in sync isolate',
        ),
        () => logger.error(
          LogDomain.sync,
          any<Object>(that: startsWith('sync isolate exited unexpectedly')),
          subDomain: 'isolate',
        ),
      ]);
    });

    test('consecutive crashes climb the backoff and then stay on its last '
        'step', () async {
      final host = makeHost(
        entry: _exitOnRequest,
        respawnBackoff: const [Duration(seconds: 1), Duration(seconds: 5)],
      );
      await startRunning(host);

      await crash(host);
      await respawn(host);
      await crash(host);
      await respawn(host);
      await crash(host);

      expect(timers.delays, const [
        Duration(seconds: 1),
        Duration(seconds: 5),
        Duration(seconds: 5),
      ]);
    });

    test('a crash after a stable run starts the backoff over', () async {
      var now = DateTime(2026, 10, 20, 9);
      await withClock(Clock(() => now), () async {
        final host = makeHost(
          entry: _exitOnRequest,
          respawnBackoff: const [Duration(seconds: 1), Duration(seconds: 5)],
          stableUptime: const Duration(minutes: 5),
        );
        await startRunning(host);
        await crash(host);
        await respawn(host);

        // The respawned worker runs past the stable uptime before it dies.
        now = now.add(const Duration(minutes: 6));
        await crash(host);

        expect(timers.delays, const [
          Duration(seconds: 1),
          Duration(seconds: 1),
        ]);
      });
    });

    test('disposing while a respawn is pending cancels it', () async {
      final host = makeHost(entry: _exitOnRequest);
      await startRunning(host);
      await crash(host);

      await host.dispose();

      expect(timers.lastCancelled, isTrue);
      expect(host.state, SyncIsolateState.disposed);
      await expectLater(
        host.ping(),
        _failsWith(SyncIsolateErrorCode.notRunning),
      );
    });
  });

  group('hosting the stack', () {
    test("answers the worker's question from the host services on the "
        'command port', () async {
      final host = makeHost(entry: _asksTheHost, services: _FakeHostServices());
      final logged = <String>[];
      when(
        () => logger.log(
          any(),
          captureAny(that: startsWith('reply ')),
          subDomain: 'isolate.asked',
          level: any(named: 'level'),
        ),
      ).thenAnswer((invocation) {
        logged.add(invocation.positionalArguments[1] as String);
      });
      host.start();
      await host.states.firstWhere((s) => s == SyncIsolateState.running);
      await untilCalled(
        () => logger.log(
          any(),
          any(that: startsWith('reply ')),
          subDomain: 'isolate.asked',
          level: any(named: 'level'),
        ),
      );

      expect(logged, ['reply 41 result=room-value failure=null']);
      await host.dispose();
    });

    test('every question the stack can ask is answered by its host service, '
        'argument for argument', () async {
      final host = makeHost(
        entry: _asksEverything,
        services: _AnswersEverything(),
      );
      final logged = <String>[];
      when(
        () => logger.log(
          any(),
          captureAny(that: startsWith('reply ')),
          subDomain: 'isolate.asked',
          level: any(named: 'level'),
        ),
      ).thenAnswer((invocation) {
        logged.add(invocation.positionalArguments[1] as String);
      });
      host.start();
      await host.states.firstWhere((s) => s == SyncIsolateState.running);
      await untilCalled(
        () => logger.log(
          any(),
          any(that: startsWith('reply 8 ')),
          subDomain: 'isolate.asked',
          level: any(named: 'level'),
        ),
      );

      expect(
        logged,
        unorderedEquals([
          'reply 1 result=room-value failure=null',
          'reply 2 result=1 failure=null',
          'reply 3 result=null failure=null',
          'reply 4 result={} failure=null',
          'reply 5 result=null failure=null',
          'reply 6 result=true failure=null',
          'reply 7 result=host-1 failure=null',
          'reply 8 result=true failure=null',
        ]),
      );
      await host.dispose();
    });

    test("a question the services cannot answer fails the worker's query and "
        'is logged', () async {
      final host = makeHost(entry: _asksTheHost)..start();
      await host.states.firstWhere((s) => s == SyncIsolateState.running);
      await untilCalled(
        () => logger.log(
          any(),
          any(that: startsWith('reply 41 result=null failure=')),
          subDomain: 'isolate.asked',
          level: any(named: 'level'),
        ),
      );

      verify(
        () => logger.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'isolate.hostRequest',
          message: 'SyncIsolateHostSettingsGet failed',
        ),
      ).called(1);
      await host.dispose();
    });

    test("send answers any command, and the worker's events reach the events "
        'stream', () async {
      final host = makeHost(entry: _asksTheHost, services: _FakeHostServices());
      final events = <SyncIsolateEvent>[];
      host.events.listen(events.add);
      host.start();
      await host.states.firstWhere((s) => s == SyncIsolateState.running);

      expect(await host.send(const SyncIsolateGetRoom()), '!room:example.org');
      await host.ping();
      await pumpEventQueue();

      expect(
        events.map((e) => e.runtimeType),
        [SyncIsolateRoomIdChanged, SyncIsolateStackChanged],
      );
      await host.dispose();
    });
  });

  group('the queue hand-off', () {
    test(
      'lease and settle are typed requests answered by the worker',
      () async {
        final host = makeHost(entry: _ownsTheQueue);
        await startRunning(host);

        final leased = await host.lease(maxBatch: 5);
        final applied = await host.settle([
          InboundEntryOutcome(leased[0], ApplyOutcome.applied),
          InboundEntryOutcome(leased[1], ApplyOutcome.retriable),
        ]);

        expect(leased.map((e) => e.eventId), [r'$e0', r'$e1']);
        expect(applied, 1);
      },
    );

    test('the tables the worker wrote reach tablesChanged, and its log line '
        'the sync log under its sub-domain and level', () async {
      final host = makeHost(entry: _ownsTheQueue);
      await startRunning(host);
      final tables = <List<String>>[];
      final sub = host.tablesChanged.listen(tables.add);
      addTearDown(sub.cancel);

      await host.settle(const []);
      await pumpEventQueue();

      expect(tables, [
        ['inbound_event_queue'],
      ]);
      verify(
        () => logger.log(
          LogDomain.sync,
          'settled 0',
          subDomain: 'isolate.queue',
          level: InsightLevel.warn,
        ),
      ).called(1);
    });

    test('a lease while no worker runs fails as notRunning, not as a hang', () {
      final host = makeHost(entry: _ownsTheQueue);

      expect(
        host.lease(maxBatch: 1),
        _failsWith(SyncIsolateErrorCode.notRunning),
      );
    });
  });
}
