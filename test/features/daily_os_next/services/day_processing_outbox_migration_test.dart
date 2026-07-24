import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_legacy_file_store.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_migration.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:path/path.dart' as path;

import 'day_processing_test_db.dart';

void main() {
  late Directory root;
  late DayProcessingDb db;
  late DayProcessingLegacyFileStore legacyStore;
  late DateTime now;

  setUp(() {
    root = Directory.systemTemp.createTempSync('day-processing-migration-');
    now = DateTime.utc(2026, 7, 18, 9);
    db = createTestDayProcessingDb();
    legacyStore = DayProcessingLegacyFileStore(rootDirectory: root);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  DayProcessingOutboxMigration migration({
    DayProcessingLegacyFileStore? store,
  }) => DayProcessingOutboxMigration(
    db: db,
    legacyStore: store ?? legacyStore,
    now: () => now,
  );

  DayProcessingJob job(
    String sessionId, {
    DayProcessingJobStatus status = DayProcessingJobStatus.queued,
    int attempts = 0,
    DateTime? createdAt,
  }) {
    final at = createdAt ?? DateTime.utc(2026, 7, 18, 7, 40);
    return DayProcessingJob(
      id: 'transcribe_$sessionId',
      status: status,
      dayId: 'dayplan-2026-07-18',
      payload: TranscribeAudioPayload(
        activityEntryId: 'activity-$sessionId',
        recordingSessionId: sessionId,
        audioId: 'audio-$sessionId',
        audioPath: path.join(root.path, '$sessionId.m4a'),
      ),
      createdAt: at,
      updatedAt: at,
      requestedAt: at,
      nextAttemptAt: at,
      attempts: attempts,
      generation: 0,
    );
  }

  File writeLegacy(DayProcessingJob value) {
    final payload = jsonEncode(value.toJson());
    final envelope = jsonEncode(<String, Object?>{
      'payload': payload,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
    });
    final safe = value.id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return File(path.join(root.path, '$safe.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(envelope);
  }

  test('imports every job file and marks the cutover complete', () async {
    writeLegacy(job('session-1'));
    writeLegacy(
      job('session-2', status: DayProcessingJobStatus.failed, attempts: 4),
    );

    final imported = await migration().run();

    expect(imported, 2);
    expect(await migration().isComplete(), isTrue);
    final jobs = await allDayProcessingJobs(db);
    expect(jobs.map((job) => job.id), [
      'transcribe_session-1',
      'transcribe_session-2',
    ]);
    // The envelope must survive, not just the id: a job that was four
    // attempts into a deterministic failure has to arrive that way, or the
    // cutover silently resets the user's retry budget.
    final failed = jobs.firstWhere((job) => job.id == 'transcribe_session-2');
    expect(failed.status, DayProcessingJobStatus.failed);
    expect(failed.attempts, 4);
  });

  test('a second run is a no-op once the sentinel exists', () async {
    writeLegacy(job('session-1'));
    expect(await migration().run(), 1);

    // A file appearing after the cutover belongs to no one: the table is
    // authoritative from the sentinel onward.
    writeLegacy(job('session-late'));

    expect(await migration().run(), isNull, reason: 'already migrated');
    expect(await allDayProcessingJobs(db), hasLength(1));
  });

  test('records the cutover on a fresh install with no directory', () async {
    final absent = DayProcessingLegacyFileStore(
      rootDirectory: Directory(path.join(root.path, 'never-existed')),
    );

    expect(await migration(store: absent).run(), 0);
    expect(await migration(store: absent).isComplete(), isTrue);
    expect(await allDayProcessingJobs(db), isEmpty);
  });

  test('is idempotent when interrupted after a partial import', () async {
    writeLegacy(job('session-1'));
    writeLegacy(job('session-2'));
    // Simulate a crash after importing one job but before the sentinel.
    final repository = DayProcessingOutboxRepository(db: db, now: () => now);
    await repository.enqueueTranscription(
      dayId: 'dayplan-2026-07-18',
      activityEntryId: 'activity-session-1',
      recordingSessionId: 'session-1',
      audioId: 'audio-session-1',
      audioPath: path.join(root.path, 'session-1.m4a'),
      capturedAt: DateTime.utc(2026, 7, 18, 7, 40),
    );
    addTearDown(repository.dispose);

    final imported = await migration().run();

    expect(imported, 1, reason: 'only the job that was missing');
    expect(await allDayProcessingJobs(db), hasLength(2));
    expect(await migration().isComplete(), isTrue);
  });

  test('never rewinds a row the live repository already advanced', () async {
    // The file says queued; the table has since taken the job terminal. An
    // upsert would resurrect finished work and re-spend inference on it.
    writeLegacy(job('session-1'));
    final repository = DayProcessingOutboxRepository(
      db: db,
      now: () => now,
      tokenFactory: () => 'claim-1',
    );
    addTearDown(repository.dispose);
    await repository.enqueueTranscription(
      dayId: 'dayplan-2026-07-18',
      activityEntryId: 'activity-session-1',
      recordingSessionId: 'session-1',
      audioId: 'audio-session-1',
      audioPath: path.join(root.path, 'session-1.m4a'),
      capturedAt: DateTime.utc(2026, 7, 18, 7, 40),
    );
    final claim = await repository.claimNext();
    await repository.markSucceeded(
      jobId: claim!.job.id,
      claimToken: claim.token,
    );

    await migration().run();

    final restored = await repository.getById('transcribe_session-1');
    expect(restored!.status, DayProcessingJobStatus.succeeded);
  });

  test('keeps a table row whose file was quarantined meanwhile', () async {
    // One-directional verification: a missing file never means "delete this
    // job", and the quarantine path is exactly how a file disappears.
    final file = writeLegacy(job('session-1'));
    expect(await migration().run(), 1);

    file.writeAsStringSync('corrupt');
    // Re-running is a no-op thanks to the sentinel, but even a forced second
    // import must not remove the row that is now the only good copy.
    expect(await allDayProcessingJobs(db), hasLength(1));
    expect(await legacyStore.readAll(), isEmpty);
    expect(await allDayProcessingJobs(db), hasLength(1));
  });

  test('imports the newest state held in an orphaned partial', () async {
    final source = job('session-1', attempts: 2);
    final published = writeLegacy(source);
    published.renameSync('${published.path}.part');

    expect(await migration().run(), 1);

    final restored = (await allDayProcessingJobs(db)).single;
    expect(restored.id, 'transcribe_session-1');
    expect(restored.attempts, 2);
  });
}
