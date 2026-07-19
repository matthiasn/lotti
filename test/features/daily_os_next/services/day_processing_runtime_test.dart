import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;
  late DateTime now;
  late DayProcessingOutboxRepository repository;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-runtime-test-');
    now = DateTime.utc(2026, 7, 18, 8);
    repository = DayProcessingOutboxRepository(
      rootDirectory: root,
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
    root.deleteSync(recursive: true);
    final blockingFile = File(root.path)..writeAsStringSync('not a directory');
    addTearDown(() {
      if (blockingFile.existsSync()) blockingFile.deleteSync();
    });
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
}
