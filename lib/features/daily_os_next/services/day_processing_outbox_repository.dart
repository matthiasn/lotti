import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class DayProcessingClaim {
  const DayProcessingClaim({required this.job, required this.token});

  final DayProcessingJob job;
  final String token;
}

class DayProcessingIntentConflict implements Exception {
  const DayProcessingIntentConflict(this.jobId);

  final String jobId;

  @override
  String toString() =>
      'DayProcessingIntentConflict: immutable fields differ for $jobId';
}

/// File-backed, per-job processing outbox for Daily OS derived work.
///
/// Each mutation flushes an integrity envelope to a partial file before an
/// atomic rename. Jobs remain after success as the local processing ledger
/// consumed by Activity and startup repair.
class DayProcessingOutboxRepository {
  DayProcessingOutboxRepository({
    required this.rootDirectory,
    DateTime Function()? now,
    String Function()? tokenFactory,
  }) : _now = now ?? DateTime.now,
       _tokenFactory = tokenFactory ?? (() => const Uuid().v4());

  final Directory rootDirectory;
  final DateTime Function() _now;
  final String Function() _tokenFactory;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _tail = Future<void>.value();

  Stream<void> get changes => _changes.stream;

  static String transcriptionJobId(String recordingSessionId) =>
      'transcribe_$recordingSessionId';

  Future<DayProcessingJob> enqueueTranscription({
    required String dayId,
    required String activityEntryId,
    required String recordingSessionId,
    required String audioId,
    required String audioPath,
    required DateTime capturedAt,
  }) => _serialize(() async {
    await _ensureRoot();
    final id = transcriptionJobId(recordingSessionId);
    final now = _now();
    final requested = _newTranscriptionJob(
      dayId: dayId,
      activityEntryId: activityEntryId,
      recordingSessionId: recordingSessionId,
      audioId: audioId,
      audioPath: audioPath,
      capturedAt: capturedAt,
      now: now,
    );
    final existing = await _readJobOrNull(id);
    if (existing != null) {
      _validateImmutableIntent(existing, requested);
      return existing;
    }
    await _write(requested);
    _notify();
    return requested;
  });

  /// Repairs the journal-created/outbox-not-yet-published crash boundary.
  Future<bool> restoreTranscriptionIntent({
    required String dayId,
    required String activityEntryId,
    required String recordingSessionId,
    required String audioId,
    required String audioPath,
    required DateTime capturedAt,
    String? completedTranscript,
  }) => _serialize(() async {
    await _ensureRoot();
    final id = transcriptionJobId(recordingSessionId);
    final now = _now();
    final transcript = completedTranscript?.trim();
    var requested = _newTranscriptionJob(
      dayId: dayId,
      activityEntryId: activityEntryId,
      recordingSessionId: recordingSessionId,
      audioId: audioId,
      audioPath: audioPath,
      capturedAt: capturedAt,
      now: now,
    );
    final existing = await _readJobOrNull(id);
    if (existing != null) {
      _validateImmutableIntent(existing, requested);
      if (transcript == null ||
          transcript.isEmpty ||
          existing.status == DayProcessingJobStatus.succeeded) {
        return false;
      }
      requested = existing.copyWith(
        status: DayProcessingJobStatus.succeeded,
        updatedAt: now,
        generation: existing.generation + 1,
        resultTranscript: transcript,
        completedAt: now,
        clearClaimToken: true,
        clearLeaseUntil: true,
        clearLastError: true,
        clearLastFailureClass: true,
      );
    }
    if (existing == null && transcript != null && transcript.isNotEmpty) {
      requested = requested.copyWith(
        status: DayProcessingJobStatus.succeeded,
        updatedAt: now,
        generation: 1,
        resultTranscript: transcript,
        completedAt: now,
      );
    }
    await _write(requested);
    _notify();
    return true;
  });

  /// Atomically publishes and claims a new interactive transcription job,
  /// preventing the background runner from racing the capture screen.
  Future<DayProcessingClaim?> enqueueAndClaimTranscription({
    required String dayId,
    required String activityEntryId,
    required String recordingSessionId,
    required String audioId,
    required String audioPath,
    required DateTime capturedAt,
    Duration lease = const Duration(minutes: 3),
  }) => _serialize(() async {
    await _ensureRoot();
    final id = transcriptionJobId(recordingSessionId);
    final now = _now();
    final existing = await _readJobOrNull(id);
    final requested = _newTranscriptionJob(
      dayId: dayId,
      activityEntryId: activityEntryId,
      recordingSessionId: recordingSessionId,
      audioId: audioId,
      audioPath: audioPath,
      capturedAt: capturedAt,
      now: now,
    );
    if (existing != null) _validateImmutableIntent(existing, requested);
    final job = existing ?? requested;
    if (existing == null) await _write(job);
    if (!job.isDue(now)) return null;
    return _claimUnsafe(job, now: now, lease: lease);
  });

  void _validateImmutableIntent(
    DayProcessingJob existing,
    DayProcessingJob requested,
  ) {
    if (existing.kind != requested.kind ||
        existing.dayId != requested.dayId ||
        existing.activityEntryId != requested.activityEntryId ||
        existing.recordingSessionId != requested.recordingSessionId ||
        existing.audioId != requested.audioId ||
        path.normalize(existing.audioPath) !=
            path.normalize(requested.audioPath) ||
        existing.createdAt != requested.createdAt) {
      throw DayProcessingIntentConflict(existing.id);
    }
  }

  DayProcessingJob _newTranscriptionJob({
    required String dayId,
    required String activityEntryId,
    required String recordingSessionId,
    required String audioId,
    required String audioPath,
    required DateTime capturedAt,
    required DateTime now,
  }) => DayProcessingJob(
    id: transcriptionJobId(recordingSessionId),
    kind: DayProcessingJobKind.transcribeAudio,
    status: DayProcessingJobStatus.queued,
    dayId: dayId,
    activityEntryId: activityEntryId,
    recordingSessionId: recordingSessionId,
    audioId: audioId,
    audioPath: path.normalize(File(audioPath).absolute.path),
    createdAt: capturedAt,
    updatedAt: now,
    nextAttemptAt: now,
    attempts: 0,
    generation: 0,
  );

  Future<List<DayProcessingJob>> getAll() => _serialize(() async {
    await _ensureRoot();
    await _recoverPartials();
    final jobs = <DayProcessingJob>[];
    for (final file in rootDirectory.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        jobs.add(await _readFile(file));
      } catch (_) {
        await _quarantine(file);
      }
    }
    jobs.sort((a, b) {
      final byCreated = a.createdAt.compareTo(b.createdAt);
      return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
    });
    return List<DayProcessingJob>.unmodifiable(jobs);
  });

  Future<DayProcessingJob?> getById(String id) =>
      _serialize(() => _readJobOrNull(id));

  Future<DayProcessingClaim?> claimNext({
    Duration lease = const Duration(minutes: 3),
  }) => _serialize(() async {
    final now = _now();
    final jobs = await _readAllUnsafe();
    final due = jobs.where((job) => job.isDue(now)).firstOrNull;
    if (due == null) return null;
    return _claimUnsafe(due, now: now, lease: lease);
  });

  /// Claims one known job for an interactive foreground attempt.
  Future<DayProcessingClaim?> claimById(
    String jobId, {
    Duration lease = const Duration(minutes: 3),
  }) => _serialize(() async {
    final now = _now();
    final job = await _readJobOrNull(jobId);
    if (job == null || !job.isDue(now)) return null;
    return _claimUnsafe(job, now: now, lease: lease);
  });

  Future<DayProcessingClaim> _claimUnsafe(
    DayProcessingJob job, {
    required DateTime now,
    required Duration lease,
  }) async {
    final token = _tokenFactory();
    final claimed = job.copyWith(
      status: DayProcessingJobStatus.running,
      updatedAt: now,
      generation: job.generation + 1,
      claimToken: token,
      leaseUntil: now.add(lease),
      clearLastError: true,
      clearLastFailureClass: true,
    );
    await _write(claimed);
    _notify();
    return DayProcessingClaim(job: claimed, token: token);
  }

  Future<DayProcessingJob> markSucceeded({
    required String jobId,
    required String claimToken,
  }) => _updateClaimed(jobId, claimToken, (job, now) {
    return job.copyWith(
      status: DayProcessingJobStatus.succeeded,
      updatedAt: now,
      generation: job.generation + 1,
      completedAt: now,
      clearClaimToken: true,
      clearLeaseUntil: true,
      clearLastError: true,
      clearLastFailureClass: true,
    );
  });

  /// Persists provider output before attempting the journal side effect, so a
  /// local database failure can retry without repeating remote inference.
  Future<DayProcessingJob> markTranscriptReady({
    required String jobId,
    required String claimToken,
    required String transcript,
  }) => _updateClaimed(jobId, claimToken, (job, now) {
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(transcript, 'transcript');
    }
    return job.copyWith(
      updatedAt: now,
      generation: job.generation + 1,
      attempts: job.attempts + 1,
      resultTranscript: trimmed,
    );
  });

  Future<DayProcessingJob> markFailure({
    required String jobId,
    required String claimToken,
    required DayProcessingFailureClass failureClass,
    required String error,
    Duration? retryAfter,
    Duration retryDelay = const Duration(seconds: 5),
  }) => _updateClaimed(jobId, claimToken, (job, now) {
    final requestAttempted =
        failureClass != DayProcessingFailureClass.network &&
        failureClass != DayProcessingFailureClass.missingAsset &&
        failureClass != DayProcessingFailureClass.local;
    final nextAttempts = job.attempts + (requestAttempted ? 1 : 0);
    final retryNotBefore = retryAfter == null ? null : now.add(retryAfter);
    final nextAttemptAt = retryNotBefore ?? now.add(retryDelay);
    final status = switch (failureClass) {
      DayProcessingFailureClass.network =>
        DayProcessingJobStatus.waitingForNetwork,
      DayProcessingFailureClass.setupRequired =>
        DayProcessingJobStatus.waitingForUser,
      DayProcessingFailureClass.missingAsset =>
        DayProcessingJobStatus.waitingForUser,
      DayProcessingFailureClass.deterministic => DayProcessingJobStatus.failed,
      _ => DayProcessingJobStatus.queued,
    };
    return job.copyWith(
      status: status,
      updatedAt: now,
      nextAttemptAt: nextAttemptAt,
      attempts: nextAttempts,
      generation: job.generation + 1,
      retryNotBefore: retryNotBefore,
      clearRetryNotBefore: retryNotBefore == null,
      lastFailureClass: failureClass,
      lastError: error,
      clearClaimToken: true,
      clearLeaseUntil: true,
    );
  });

  Future<DayProcessingJob?> retryNow(String jobId) => _serialize(() async {
    final job = await _readJobOrNull(jobId);
    if (job == null || job.isTerminal) return job;
    final now = _now();
    final hardBoundary = job.retryNotBefore;
    final due = hardBoundary != null && now.isBefore(hardBoundary)
        ? hardBoundary
        : now;
    final updated = job.copyWith(
      status: DayProcessingJobStatus.queued,
      updatedAt: now,
      nextAttemptAt: due,
      generation: job.generation + 1,
      clearClaimToken: true,
      clearLeaseUntil: true,
      clearLastError: true,
      clearLastFailureClass: true,
    );
    await _write(updated);
    _notify();
    return updated;
  });

  /// Marks transcription as satisfied by canonical user-reviewed text.
  /// Pending provider work is fenced and will not later overwrite the user's
  /// decision or spend inference tokens unnecessarily.
  Future<DayProcessingJob?> satisfyWithReviewedText(
    String jobId,
    String transcript,
  ) => _serialize(() async {
    final job = await _readJobOrNull(jobId);
    if (job == null || job.isTerminal) return job;
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return job;
    final now = _now();
    final updated = job.copyWith(
      status: DayProcessingJobStatus.succeeded,
      updatedAt: now,
      generation: job.generation + 1,
      resultTranscript: trimmed,
      completedAt: now,
      clearClaimToken: true,
      clearLeaseUntil: true,
      clearRetryNotBefore: true,
      clearLastError: true,
      clearLastFailureClass: true,
    );
    await _write(updated);
    _notify();
    return updated;
  });

  Future<void> signalConnectivityRestored() => _serialize(() async {
    final now = _now();
    for (final job in await _readAllUnsafe()) {
      if (job.status != DayProcessingJobStatus.waitingForNetwork) continue;
      final updated = job.copyWith(
        status: DayProcessingJobStatus.queued,
        updatedAt: now,
        nextAttemptAt: now,
        generation: job.generation + 1,
      );
      await _write(updated);
    }
    _notify();
  });

  Future<DayProcessingJob> _updateClaimed(
    String jobId,
    String claimToken,
    DayProcessingJob Function(DayProcessingJob job, DateTime now) update,
  ) => _serialize(() async {
    final job = await _readJobOrNull(jobId);
    if (job == null) throw StateError('Unknown processing job $jobId');
    if (job.status != DayProcessingJobStatus.running ||
        job.claimToken != claimToken) {
      throw StateError('Processing claim no longer owns $jobId');
    }
    final updated = update(job, _now());
    await _write(updated);
    _notify();
    return updated;
  });

  Future<List<DayProcessingJob>> _readAllUnsafe() async {
    await _ensureRoot();
    await _recoverPartials();
    final jobs = <DayProcessingJob>[];
    for (final file in rootDirectory.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      try {
        jobs.add(await _readFile(file));
      } catch (_) {
        await _quarantine(file);
      }
    }
    jobs.sort((a, b) {
      final byDue = a.nextAttemptAt.compareTo(b.nextAttemptAt);
      return byDue != 0 ? byDue : a.id.compareTo(b.id);
    });
    return jobs;
  }

  Future<DayProcessingJob?> _readJobOrNull(String id) async {
    await _ensureRoot();
    final file = _fileFor(id);
    if (!file.existsSync()) return null;
    try {
      return await _readFile(file);
    } catch (_) {
      await _quarantine(file);
      return null;
    }
  }

  Future<DayProcessingJob> _readFile(File file) async {
    final envelope =
        jsonDecode(await file.readAsString())! as Map<String, Object?>;
    final payload = envelope['payload']! as String;
    final expected = envelope['sha256']! as String;
    final actual = sha256.convert(utf8.encode(payload)).toString();
    if (actual != expected) {
      throw const FormatException('Invalid processing job digest');
    }
    return DayProcessingJob.fromJson(
      jsonDecode(payload)! as Map<String, Object?>,
    );
  }

  Future<void> _write(DayProcessingJob job) async {
    await _ensureRoot();
    final destination = _fileFor(job.id);
    final payload = jsonEncode(job.toJson());
    final envelope = jsonEncode(<String, Object?>{
      'payload': payload,
      'sha256': sha256.convert(utf8.encode(payload)).toString(),
    });
    await atomicWriteString(
      text: envelope,
      filePath: destination.path,
      subDomain: 'daily_os.processing_outbox',
    );
  }

  Future<void> _recoverPartials() async {
    for (final partial in rootDirectory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.json.part'),
    )) {
      final destination = File(
        partial.path.substring(0, partial.path.length - '.part'.length),
      );
      if (destination.existsSync()) {
        await partial.delete();
        continue;
      }
      try {
        await _readFile(partial);
        await partial.rename(destination.path);
      } catch (_) {
        await _quarantine(partial);
      }
    }
  }

  Future<void> _quarantine(File file) async {
    final quarantine = Directory(path.join(rootDirectory.path, 'quarantine'));
    await quarantine.create(recursive: true);
    final destination = File(
      path.join(quarantine.path, path.basename(file.path)),
    );
    if (destination.existsSync()) await destination.delete();
    await file.rename(destination.path);
  }

  File _fileFor(String id) {
    final safe = id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return File(path.join(rootDirectory.path, '$safe.json'));
  }

  Future<void> _ensureRoot() => rootDirectory.create(recursive: true);

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
