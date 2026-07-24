import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/database/day_processing_db.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_startup.dart';
import 'package:path/path.dart' as path;

import 'day_processing_test_db.dart';

void main() {
  late Directory documents;
  late DayProcessingDb db;

  setUp(() {
    documents = Directory.systemTemp.createTempSync('day-processing-startup-');
    db = createTestDayProcessingDb();
  });

  tearDown(() {
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  void writeLegacyJob(String sessionId) {
    final at = DateTime.utc(2026, 7, 18, 7, 40);
    final job = DayProcessingJob(
      id: 'transcribe_$sessionId',
      status: DayProcessingJobStatus.queued,
      dayId: 'dayplan-2026-07-18',
      payload: TranscribeAudioPayload(
        activityEntryId: 'activity-$sessionId',
        recordingSessionId: sessionId,
        audioId: 'audio-$sessionId',
        audioPath: path.join(documents.path, '$sessionId.m4a'),
      ),
      createdAt: at,
      updatedAt: at,
      requestedAt: at,
      nextAttemptAt: at,
      attempts: 0,
      generation: 0,
    );
    final payload = jsonEncode(job.toJson());
    final directory = Directory(
      path.join(documents.path, legacyDayProcessingOutboxDirectory),
    )..createSync(recursive: true);
    File(
      path.join(directory.path, 'transcribe_$sessionId.json'),
    ).writeAsStringSync(
      jsonEncode(<String, Object?>{
        'payload': payload,
        'sha256': sha256.convert(utf8.encode(payload)).toString(),
      }),
    );
  }

  test('carries the legacy directory into the table before use', () async {
    writeLegacyJob('session-1');

    final repository = await initializeDayProcessingOutbox(
      db: db,
      documentsDirectory: documents,
    );
    addTearDown(repository.dispose);

    // The repository handed back must already see the migrated work, or the
    // runtime would start against an empty outbox and the user's pending
    // recording would look lost.
    expect(
      (await repository.getById('transcribe_session-1'))!.dayId,
      'dayplan-2026-07-18',
    );
  });

  test('starts clean when no legacy directory exists', () async {
    final repository = await initializeDayProcessingOutbox(
      db: db,
      documentsDirectory: documents,
    );
    addTearDown(repository.dispose);

    expect(await allDayProcessingJobs(db), isEmpty);
    expect(
      Directory(
        path.join(documents.path, legacyDayProcessingOutboxDirectory),
      ).existsSync(),
      isFalse,
      reason: 'startup must not recreate the store it is retiring',
    );
  });

  test('is safe to run again on a later start', () async {
    writeLegacyJob('session-1');
    final first = await initializeDayProcessingOutbox(
      db: db,
      documentsDirectory: documents,
    );
    addTearDown(first.dispose);

    final second = await initializeDayProcessingOutbox(
      db: db,
      documentsDirectory: documents,
    );
    addTearDown(second.dispose);

    expect(await allDayProcessingJobs(db), hasLength(1));
  });
}
