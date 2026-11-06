import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

import '../../../mocks/mocks.dart';
import 'day_processing_test_db.dart';

void main() {
  late Directory root;
  late DateTime now;
  late DayProcessingDb db;
  late DayProcessingOutboxRepository repository;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-runtime-test-');
    now = DateTime.utc(2026, 7, 18, 8);
    db = createTestDayProcessingDb();
    repository = DayProcessingOutboxRepository(
      db: db,
      now: () => now,
      tokenFactory: () => 'claim-1',
    );
    await repository.enqueueTranscription(
      dayId: 'dayplan-2026-07-18',
      activityEntryId: 'activity-1',
      recordingSessionId: 'session-1',
      audioId: 'audio-1',
      audioPath: path.join(root.path, 'audio.wav'),
      capturedAt: now,
    );
  });

  tearDown(() async {
    await repository.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'nudge coalesces concurrent drains and schedules the next due job',
    () async {
      final release = Completer<void>();
      var drains = 0;
      Duration? scheduledDelay;
      final runtime = DayProcessingRuntime(
        repository: repository,
        now: () => now,
        drain: () async {
          drains += 1;
          await release.future;
          return 0;
        },
        schedule: (delay, _) => scheduledDelay = delay,
      );
      addTearDown(runtime.dispose);

      final first = runtime.nudge();
      final second = runtime.nudge();
      release.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(drains, 1);
      expect(scheduledDelay, Duration.zero);
    },
  );

  test(
    'outbox change during an active drain triggers an immediate follow-up',
    () async {
      final firstDrainStarted = Completer<void>();
      final releaseFirstDrain = Completer<void>();
      final secondDrainCompleted = Completer<void>();
      void Function()? scheduledCallback;
      var drains = 0;
      final runtime = DayProcessingRuntime(
        repository: repository,
        now: () => now,
        connectivityChanges: const Stream.empty(),
        drain: () async {
          drains += 1;
          if (drains == 1) {
            final claim = await repository.claimNext();
            await repository.markSucceeded(
              jobId: claim!.job.id,
              claimToken: claim.token,
            );
            firstDrainStarted.complete();
            await releaseFirstDrain.future;
          } else if (drains == 2) {
            final claim = await repository.claimNext();
            await repository.markSucceeded(
              jobId: claim!.job.id,
              claimToken: claim.token,
            );
            secondDrainCompleted.complete();
          }
          return 0;
        },
        schedule: (_, callback) => scheduledCallback = callback,
      );
      addTearDown(runtime.dispose);

      runtime.start();
      final firstNudge = runtime.nudge();
      await firstDrainStarted.future;
      await repository.enqueueParseCapture(
        dayId: 'dayplan-2026-07-18',
        captureId: 'capture-arrived-during-drain',
      );
      releaseFirstDrain.complete();
      await firstNudge;
      scheduledCallback!();
      await secondDrainCompleted.future;

      expect(drains, 2);
    },
  );

  test('drain-owned outbox mutations do not request another drain', () async {
    var drains = 0;
    final runtime = DayProcessingRuntime(
      repository: repository,
      now: () => now,
      connectivityChanges: const Stream.empty(),
      drain: () async {
        drains += 1;
        final claim = await repository.claimNext();
        if (claim != null) {
          await repository.markSucceeded(
            jobId: claim.job.id,
            claimToken: claim.token,
          );
        }
        return claim == null ? 0 : 1;
      },
      schedule: (_, _) {},
    );
    addTearDown(runtime.dispose);

    runtime.start();
    await runtime.nudge();
    await Future<void>.value();

    expect(drains, 1);
    expect(
      (await repository.getById('transcribe_session-1'))!.status,
      DayProcessingJobStatus.succeeded,
    );
  });

  test(
    'external change after drain mutation phase requests one follow-up',
    () async {
      final changes = StreamController<void>.broadcast(sync: true);
      final outbox = MockDayProcessingOutboxRepository();
      final firstQueryStarted = Completer<void>();
      final releaseFirstQuery = Completer<void>();
      var drains = 0;
      var queries = 0;
      when(() => outbox.changes).thenAnswer((_) => changes.stream);
      when(outbox.getSchedulable).thenAnswer((_) async {
        queries += 1;
        if (queries == 1) {
          firstQueryStarted.complete();
          await releaseFirstQuery.future;
        }
        return const [];
      });

      final runtime = DayProcessingRuntime(
        repository: outbox,
        connectivityChanges: const Stream.empty(),
        drain: () async {
          drains += 1;
          return 0;
        },
        schedule: (_, _) {},
      );
      addTearDown(() async {
        await runtime.dispose();
        await changes.close();
      });

      runtime.start();
      final firstNudge = runtime.nudge();
      await firstQueryStarted.future;
      changes.add(null);
      releaseFirstQuery.complete();
      await firstNudge;
      for (var i = 0; i < 3; i++) {
        await Future<void>.value();
      }

      expect(drains, 2);
      expect(queries, 2);
    },
  );

  test('failed drain restores the outbox change listener', () async {
    final changes = StreamController<void>.broadcast(sync: true);
    final outbox = MockDayProcessingOutboxRepository();
    var drains = 0;
    var queries = 0;
    Duration? scheduledDelay;
    when(() => outbox.changes).thenAnswer((_) => changes.stream);
    when(outbox.getSchedulable).thenAnswer((_) async {
      queries += 1;
      return const [];
    });

    final runtime = DayProcessingRuntime(
      repository: outbox,
      connectivityChanges: const Stream.empty(),
      failureRetryDelay: const Duration(seconds: 17),
      drain: () async {
        drains += 1;
        if (drains == 1) {
          throw StateError('drain failed');
        }
        return 0;
      },
      schedule: (delay, _) => scheduledDelay = delay,
    );
    addTearDown(() async {
      await runtime.dispose();
      await changes.close();
    });

    runtime.start();
    await runtime.nudge();
    expect(scheduledDelay, const Duration(seconds: 17));

    changes.add(null);
    for (var i = 0; i < 3; i++) {
      await Future<void>.value();
    }

    expect(drains, 2);
    expect(queries, 1);
  });

  test(
    'connectivity restoration advances offline work and drains it',
    () async {
      final claim = await repository.claimNext();
      await repository.markFailure(
        jobId: claim!.job.id,
        claimToken: claim.token,
        failureClass: DayProcessingFailureClass.network,
        error: 'offline',
      );
      var drains = 0;
      final runtime = DayProcessingRuntime(
        repository: repository,
        now: () => now,
        drain: () async {
          drains += 1;
          return 0;
        },
        schedule: (_, _) {},
      );
      addTearDown(runtime.dispose);

      await runtime.handleConnectivityRestored();
      final job = await repository.getById('transcribe_session-1');

      expect(drains, 1);
      expect(job!.status, DayProcessingJobStatus.queued);
      expect(job.nextAttemptAt, now);
    },
  );

  test(
    'network wait schedules a safety probe without an interface event',
    () async {
      final claim = await repository.claimNext();
      await repository.markFailure(
        jobId: claim!.job.id,
        claimToken: claim.token,
        failureClass: DayProcessingFailureClass.network,
        error: 'captive portal',
      );
      Duration? scheduledDelay;
      void Function()? scheduledCallback;
      var drains = 0;
      final runtime = DayProcessingRuntime(
        repository: repository,
        now: () => now,
        networkProbeInterval: const Duration(minutes: 2),
        drain: () async {
          drains += 1;
          return 0;
        },
        schedule: (delay, callback) {
          scheduledDelay = delay;
          scheduledCallback = callback;
        },
      );
      addTearDown(runtime.dispose);

      await runtime.nudge();
      expect(scheduledDelay, const Duration(minutes: 2));
      now = now.add(const Duration(minutes: 2));
      final connectivityAdvance = repository.changes.first;
      scheduledCallback!();
      await connectivityAdvance;
      await runtime.nudge();

      expect(drains, 2);
      expect(
        (await repository.getById('transcribe_session-1'))!.status,
        DayProcessingJobStatus.queued,
      );
    },
  );

  test('runtime failures are contained and rescheduled', () async {
    Duration? scheduledDelay;
    final runtime = DayProcessingRuntime(
      repository: repository,
      failureRetryDelay: const Duration(seconds: 17),
      drain: () async => throw StateError('temporary filesystem failure'),
      schedule: (delay, _) => scheduledDelay = delay,
    );
    addTearDown(runtime.dispose);

    await runtime.nudge();

    expect(scheduledDelay, const Duration(seconds: 17));
  });

  test('connectivity repair failures are contained and rescheduled', () async {
    final claim = await repository.claimNext();
    await repository.markFailure(
      jobId: claim!.job.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.network,
      error: 'offline',
    );
    // Force a storage failure. Closing the database makes every subsequent
    // query throw, which is the runtime-visible shape of the outbox being
    // unusable — the runtime must contain it and reschedule rather than let
    // the error escape an unawaited connectivity callback.
    await db.close();
    Duration? scheduledDelay;
    final runtime = DayProcessingRuntime(
      repository: repository,
      failureRetryDelay: const Duration(seconds: 19),
      drain: () async => 0,
      schedule: (delay, _) => scheduledDelay = delay,
    );
    addTearDown(runtime.dispose);

    await runtime.handleConnectivityRestored();

    expect(scheduledDelay, const Duration(seconds: 19));
  });

  test('disposed runtime ignores future nudges', () async {
    var drains = 0;
    final runtime = DayProcessingRuntime(
      repository: repository,
      drain: () async {
        drains += 1;
        return 0;
      },
      schedule: (_, _) {},
    );

    await runtime.dispose();
    await runtime.nudge();

    expect(drains, 0);
  });

  test('start reacts only to connected interfaces and is idempotent', () async {
    final claim = await repository.claimNext();
    await repository.markFailure(
      jobId: claim!.job.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.network,
      error: 'offline',
    );
    final connectivity = StreamController<List<ConnectivityResult>>();
    var drains = 0;
    final runtime = DayProcessingRuntime(
      repository: repository,
      connectivityChanges: connectivity.stream,
      drain: () async {
        drains += 1;
        return 0;
      },
      schedule: (_, _) {},
    );
    addTearDown(() async {
      await runtime.dispose();
      await connectivity.close();
    });

    runtime
      ..start()
      ..start();
    await runtime.nudge();
    final startupDrains = drains;

    connectivity.add(const [ConnectivityResult.none]);
    await Future<void>.value();
    expect(
      (await repository.getById('transcribe_session-1'))!.status,
      DayProcessingJobStatus.waitingForNetwork,
    );

    final changed = repository.changes.first;
    connectivity.add(const [ConnectivityResult.wifi]);
    await changed;
    await runtime.nudge();

    expect(drains, greaterThan(startupDrains));
    expect(
      (await repository.getById('transcribe_session-1'))!.status,
      DayProcessingJobStatus.queued,
    );
  });

  test('a connectivity stream error is absorbed, and an unnamed link '
      '(WireGuard, tun) counts as restored', () async {
    final claim = await repository.claimNext();
    await repository.markFailure(
      jobId: claim!.job.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.network,
      error: 'offline',
    );
    final connectivity = StreamController<List<ConnectivityResult>>();
    final runtime = DayProcessingRuntime(
      repository: repository,
      connectivityChanges: connectivity.stream,
      drain: () async => 0,
      schedule: (_, _) {},
    );
    addTearDown(() async {
      await runtime.dispose();
      await connectivity.close();
    });
    runtime.start();
    await runtime.nudge();

    // An unhandled stream error would fail this test through the zone.
    connectivity.addError(StateError('NetworkManager was not provided'));
    await Future<void>.value();

    final changed = repository.changes.first;
    connectivity.add(const [ConnectivityResult.other]);
    await changed;

    expect(
      (await repository.getById('transcribe_session-1'))!.status,
      DayProcessingJobStatus.queued,
    );
  });

  test('a repair that fails still lets the drain run, is reported, and is '
      'retried even with nothing queued', () async {
    // An empty outbox: nothing but the pending repair needs another pass.
    await repository.cancel('transcribe_session-1');
    var repairs = 0;
    var drains = 0;
    final failures = <Object>[];
    final scheduled = <Duration>[];
    final runtime = DayProcessingRuntime(
      repository: repository,
      now: () => now,
      connectivityChanges: const Stream.empty(),
      repair: () async {
        repairs += 1;
        if (repairs == 1) throw StateError('intent conflict');
        return 0;
      },
      onRepairFailed: (error, _) => failures.add(error),
      drain: () async {
        drains += 1;
        return 0;
      },
      schedule: (delay, _) => scheduled.add(delay),
    );
    addTearDown(runtime.dispose);

    await runtime.drainAndSchedule();
    // A failed repair used to skip the drain on every pass, forever.
    expect((repairs, drains), (1, 1));
    expect(failures.single, isA<StateError>());
    expect(
      scheduled,
      [runtime.failureRetryDelay],
      reason: 'the pending repair schedules its own retry',
    );

    await runtime.drainAndSchedule();
    expect((repairs, drains), (2, 2));
    expect(scheduled, hasLength(1), reason: 'repaired: nothing left to wake');

    await runtime.drainAndSchedule();
    expect((repairs, drains), (2, 3), reason: 'repair runs once it succeeded');
  });

  test(
    'retention prunes once per start, however often the repair retries',
    () async {
      var prunes = 0;
      var repairs = 0;
      final runtime = DayProcessingRuntime(
        repository: repository,
        now: () => now,
        connectivityChanges: const Stream.empty(),
        prune: () async {
          prunes += 1;
          if (prunes == 1) throw StateError('database busy');
        },
        repair: () async {
          repairs += 1;
          if (repairs < 3) throw StateError('intent conflict');
          return 0;
        },
        drain: () async => 0,
        schedule: (_, _) {},
      );
      addTearDown(runtime.dispose);

      for (var pass = 0; pass < 4; pass++) {
        await runtime.drainAndSchedule();
      }

      expect(
        prunes,
        2,
        reason: 'a failed prune is retried, a successful one not',
      );
      expect(
        repairs,
        3,
        reason: 'the repair retries independently until it succeeds',
      );
    },
  );

  test('a pending repair retry wins over a later job deadline', () async {
    final claim = await repository.claimNext();
    await repository.markFailure(
      jobId: claim!.job.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.timeout,
      error: 'provider busy',
      retryDelay: const Duration(minutes: 10),
    );
    final scheduled = <Duration>[];
    final runtime = DayProcessingRuntime(
      repository: repository,
      now: () => now,
      connectivityChanges: const Stream.empty(),
      repair: () async => throw StateError('intent conflict'),
      drain: () async => 0,
      schedule: (delay, _) => scheduled.add(delay),
    );
    addTearDown(runtime.dispose);

    await runtime.drainAndSchedule();

    expect(scheduled, [runtime.failureRetryDelay]);
  });

  test('an earlier job deadline wins over a pending repair retry', () async {
    final scheduled = <Duration>[];
    final runtime = DayProcessingRuntime(
      repository: repository,
      now: () => now,
      connectivityChanges: const Stream.empty(),
      repair: () async => throw StateError('intent conflict'),
      drain: () async => 0,
      schedule: (delay, _) => scheduled.add(delay),
    );
    addTearDown(runtime.dispose);

    // The setUp transcription job is due now.
    await runtime.drainAndSchedule();

    expect(scheduled, [Duration.zero]);
  });

  test('running work is scheduled at its lease boundary', () async {
    final claim = await repository.claimNext();
    Duration? scheduledDelay;
    final runtime = DayProcessingRuntime(
      repository: repository,
      now: () => now,
      drain: () async => 0,
      schedule: (delay, _) => scheduledDelay = delay,
    );
    addTearDown(runtime.dispose);

    await runtime.nudge();

    expect(claim!.job.status, DayProcessingJobStatus.running);
    expect(scheduledDelay, const Duration(minutes: 3));
  });

  test('a restored network cannot bypass a provider retry boundary', () async {
    final claim = await repository.claimNext();
    await repository.markFailure(
      jobId: claim!.job.id,
      claimToken: claim.token,
      failureClass: DayProcessingFailureClass.network,
      error: 'HTTP 429 after reconnect',
      retryAfter: const Duration(minutes: 2),
    );
    await repository.signalConnectivityRestored();
    Duration? scheduledDelay;
    final runtime = DayProcessingRuntime(
      repository: repository,
      now: () => now,
      drain: () async => 0,
      schedule: (delay, _) => scheduledDelay = delay,
    );
    addTearDown(runtime.dispose);

    await runtime.nudge();

    expect(scheduledDelay, const Duration(minutes: 2));
  });

  test('a due-work callback nudges the runtime again', () async {
    void Function()? scheduledCallback;
    final secondDrain = Completer<void>();
    var drains = 0;
    final runtime = DayProcessingRuntime(
      repository: repository,
      now: () => now,
      drain: () async {
        drains += 1;
        if (drains == 2) secondDrain.complete();
        return 0;
      },
      schedule: (_, callback) => scheduledCallback = callback,
    );
    addTearDown(runtime.dispose);

    await runtime.nudge();
    scheduledCallback!();
    await secondDrain.future;

    expect(drains, 2);
  });
}
