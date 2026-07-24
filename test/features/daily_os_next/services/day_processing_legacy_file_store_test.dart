import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_legacy_file_store.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;
  late DayProcessingLegacyFileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('day-processing-legacy-test-');
    store = DayProcessingLegacyFileStore(rootDirectory: root);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  DayProcessingJob job(
    String sessionId, {
    DateTime? createdAt,
    DayProcessingJobStatus status = DayProcessingJobStatus.queued,
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
      attempts: 0,
      generation: 0,
    );
  }

  /// Writes the pre-ADR-0044 envelope: the job JSON plus its digest.
  File writeLegacy(DayProcessingJob value, {String suffix = '.json'}) {
    final payload = jsonEncode(value.toJson());
    final envelope = jsonEncode(<String, Object?>{
      'payload': payload,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
    });
    final safe = value.id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return File(path.join(root.path, '$safe$suffix'))
      ..createSync(recursive: true)
      ..writeAsStringSync(envelope);
  }

  test('reports a missing directory rather than creating one', () async {
    final absent = DayProcessingLegacyFileStore(
      rootDirectory: Directory(path.join(root.path, 'nope')),
    );

    expect(absent.exists, isFalse);
    expect(await absent.readAll(), isEmpty);
    expect(Directory(path.join(root.path, 'nope')).existsSync(), isFalse);
  });

  test('reads jobs oldest first with the id as tie-break', () async {
    final base = DateTime.utc(2026, 7, 18, 7, 40);
    writeLegacy(job('session-b'));
    writeLegacy(job('session-a'));
    writeLegacy(
      job('session-0', createdAt: base.subtract(const Duration(hours: 1))),
    );

    final jobs = await store.readAll();

    expect(jobs.map((job) => job.id), [
      'transcribe_session-0',
      'transcribe_session-a',
      'transcribe_session-b',
    ]);
  });

  test('round-trips the full envelope, not just the id', () async {
    final source = job(
      'session-1',
      status: DayProcessingJobStatus.waitingForNetwork,
    ).copyWith(attempts: 3, generation: 7, lastError: 'Offline');
    writeLegacy(source);

    final restored = (await store.readAll()).single;

    expect(restored.status, DayProcessingJobStatus.waitingForNetwork);
    expect(restored.attempts, 3);
    expect(restored.generation, 7);
    expect(restored.lastError, 'Offline');
    expect(
      (restored.payload as TranscribeAudioPayload).recordingSessionId,
      'session-1',
    );
  });

  test('reads an orphaned partial that has no published file', () async {
    final source = job('session-1');
    final target = writeLegacy(source);
    target.renameSync('${target.path}.part');

    final jobs = await store.readAll();

    expect(jobs.single.id, source.id);
  });

  test('prefers the newer generation when both copies exist', () async {
    // A crash between the scratch write and the rename leaves both files, and
    // the scratch one holds the newer state.
    final published = writeLegacy(job('session-1'));
    writeLegacy(
      job('session-1').copyWith(
        generation: 4,
        attempts: 2,
        status: DayProcessingJobStatus.waitingForNetwork,
      ),
      suffix: '.json.part',
    );

    final restored = (await store.readAll()).single;

    expect(restored.generation, 4);
    expect(restored.attempts, 2);
    expect(restored.status, DayProcessingJobStatus.waitingForNetwork);
    expect(published.existsSync(), isTrue, reason: 'the read is read-only');
  });

  test('keeps the published copy when the scratch one is older', () async {
    writeLegacy(job('session-1').copyWith(generation: 6));
    writeLegacy(job('session-1'), suffix: '.json.part');

    expect((await store.readAll()).single.generation, 6);
  });

  test(
    'recovers the atomic-write scratch file the store really uses',
    () async {
      // atomicWriteBytes writes `<path>.tmp.<micros>.<pid>.media` and renames
      // over the destination. A crash in that window on a job's first write
      // leaves this as the only copy.
      writeLegacy(
        job('session-1').copyWith(generation: 3),
        suffix: '.json.tmp.1737000000000000.4242.media',
      );

      final restored = (await store.readAll()).single;

      expect(restored.id, 'transcribe_session-1');
      expect(restored.generation, 3);
    },
  );

  test('breaks a generation tie on updatedAt', () async {
    final base = job('session-1');
    writeLegacy(base);
    writeLegacy(
      base.copyWith(updatedAt: base.updatedAt.add(const Duration(minutes: 5))),
      suffix: '.json.part',
    );

    final restored = (await store.readAll()).single;

    expect(
      restored.updatedAt,
      DateTime.utc(2026, 7, 18, 7, 45),
    );
  });

  test('skips an unreadable scratch file without quarantining it', () async {
    // Half-written scratch is expected after a crash, not evidence of
    // corruption, so it is passed over rather than filed for inspection.
    File(
      path.join(root.path, 'corrupt.json.part'),
    ).writeAsStringSync('not an envelope');
    writeLegacy(job('session-1'));

    final jobs = await store.readAll();

    expect(
      jobs.single.id,
      'transcribe_session-1',
      reason: 'one bad file must not abort the whole read',
    );
    expect(
      File(
        path.join(root.path, 'quarantine', 'corrupt.json.part'),
      ).existsSync(),
      isFalse,
    );
  });

  test('quarantines a job whose digest no longer matches', () async {
    final target = writeLegacy(job('session-1'));
    // Keep the envelope shape but corrupt the payload, so only the digest
    // check can catch it.
    final envelope =
        jsonDecode(target.readAsStringSync())! as Map<String, Object?>;
    target.writeAsStringSync(
      jsonEncode(<String, Object?>{
        'payload': (envelope['payload']! as String).replaceFirst(
          'session-1',
          'tampered',
        ),
        'sha256': envelope['sha256'],
      }),
    );

    expect(await store.readAll(), isEmpty);
    expect(
      File(
        path.join(root.path, 'quarantine', path.basename(target.path)),
      ).existsSync(),
      isTrue,
    );
  });

  test('replaces an existing quarantine entry of the same name', () async {
    Directory(path.join(root.path, 'quarantine')).createSync(recursive: true);
    File(
      path.join(root.path, 'quarantine', 'corrupt.json'),
    ).writeAsStringSync('older');
    File(path.join(root.path, 'corrupt.json')).writeAsStringSync('newer');

    await store.readAll();

    expect(
      File(
        path.join(root.path, 'quarantine', 'corrupt.json'),
      ).readAsStringSync(),
      'newer',
    );
  });
}
