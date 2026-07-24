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

  test("publishes an orphaned partial as the job's newest state", () async {
    final source = job('session-1');
    final target = writeLegacy(source);
    final partial = File('${target.path}.part');
    target.renameSync(partial.path);

    final jobs = await store.readAll();

    expect(jobs.single.id, source.id);
    expect(target.existsSync(), isTrue, reason: 'partial was promoted');
    expect(partial.existsSync(), isFalse);
  });

  test('drops a stale partial beside its already-published job', () async {
    final target = writeLegacy(job('session-1'));
    final partial = File('${target.path}.part')
      ..writeAsBytesSync(target.readAsBytesSync());

    final jobs = await store.readAll();

    expect(jobs, hasLength(1));
    expect(target.existsSync(), isTrue);
    expect(partial.existsSync(), isFalse, reason: 'published file wins');
  });

  test('quarantines a corrupt orphan partial instead of failing', () async {
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
      isTrue,
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
