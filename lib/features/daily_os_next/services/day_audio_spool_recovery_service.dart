import 'dart:io';

import 'package:lotti/classes/audio_note.dart';
import 'package:lotti/classes/day_audio_context.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/speech/repository/speech_repository.dart';
import 'package:lotti/features/speech/services/durable_audio_spool.dart';
import 'package:path/path.dart' as path;

typedef PersistRecoveredDayAudio =
    Future<JournalAudio?> Function(
      AudioNote note,
    );

/// Promotes crash-recoverable Daily OS PCM spools into JournalAudio + outbox.
class DayAudioSpoolRecoveryService {
  DayAudioSpoolRecoveryService({
    required this.journalDb,
    required this.outbox,
    required this.assetRoot,
    PersistRecoveredDayAudio? persistAudio,
  }) : _persistAudio = persistAudio ?? SpeechRepository.createAudioEntry;

  final JournalDb journalDb;
  final DayProcessingOutboxRepository outbox;
  final Directory assetRoot;
  final PersistRecoveredDayAudio _persistAudio;

  Directory get _spoolRoot => Directory(
    path.join(assetRoot.path, '.audio_spool'),
  );

  Future<int> recoverAll() async {
    if (!_spoolRoot.existsSync()) return 0;
    var recovered = 0;
    for (final directory in _spoolRoot.listSync().whereType<Directory>()) {
      try {
        if (await recoverSession(path.basename(directory.path)) != null) {
          recovered += 1;
        }
      } catch (_) {
        // One damaged session must not prevent other recordings from healing.
      }
    }
    return recovered;
  }

  Future<JournalAudio?> recoverSession(String recordingSessionId) async {
    final directory = Directory(
      path.join(_spoolRoot.path, recordingSessionId),
    );
    if (!directory.existsSync()) return null;
    final recovery = await DurableAudioSpool.recover(
      sessionDirectory: directory,
    );
    final manifest = recovery.manifest;
    final spool = recovery.spool;
    final context = manifest.context;
    final dayId = context.dayId;
    final planDate = context.planDate;
    final intent = context.intent;
    if (context.origin != AudioCaptureOrigin.dailyOs ||
        dayId == null ||
        planDate == null ||
        intent == null ||
        spool == null ||
        manifest.state == DurableAudioSpoolState.quarantined ||
        manifest.acceptedPcmBytes == 0) {
      return null;
    }

    var audio = await _ownedOrExistingAudio(manifest);
    if (audio == null) {
      final destination = _recoveryDestination(manifest);
      if (destination == null) return null;
      final finalized = await spool.finalize(destinationFile: destination);
      final relativeParent = path.relative(
        destination.parent.path,
        from: assetRoot.absolute.path,
      );
      final relativeDirectory =
          '/${path.posix.normalize(relativeParent.replaceAll(r'\', '/'))}/';
      final fileName = path.basename(destination.path);
      final processingJobId = DayProcessingOutboxRepository.transcriptionJobId(
        recordingSessionId,
      );
      audio = await _persistAudio(
        AudioNote(
          createdAt: context.createdAt,
          audioFile: fileName,
          audioDirectory: relativeDirectory,
          duration: finalized.duration,
          dayContext: DayAudioContext(
            dayId: dayId,
            planDate: planDate,
            recordingSessionId: recordingSessionId,
            activityEntryId: context.activityEntryId,
            processingJobId: processingJobId,
            capturedAt: context.createdAt,
            intent: intent.name,
            originHostId: context.originHostId,
            continuationOperationId: context.continuationOperationId,
            baselineRevisionId: context.baselineRevisionId,
          ),
        ),
      );
      audio ??= await _findBySession(recordingSessionId);
      if (audio == null) return null;
    }

    final audioContext = audio.data.dayContext;
    if (audioContext == null || !_matchesManifest(audio, manifest)) {
      return null;
    }
    await spool.markCommitted(journalAudioId: audio.meta.id);
    await outbox.restoreTranscriptionIntent(
      dayId: audioContext.dayId,
      activityEntryId: audioContext.activityEntryId,
      recordingSessionId: audioContext.recordingSessionId,
      audioId: audio.meta.id,
      audioPath: path.join(
        assetRoot.path,
        audio.data.audioDirectory.replaceFirst(RegExp('^/+'), ''),
        audio.data.audioFile,
      ),
      capturedAt: audioContext.capturedAt,
      completedTranscript: _completedTranscript(audio),
    );
    return audio;
  }

  bool _matchesManifest(
    JournalAudio audio,
    DurableAudioSpoolManifest manifest,
  ) {
    final stored = audio.data.dayContext;
    final source = manifest.context;
    if (stored == null ||
        stored.recordingSessionId != source.recordingSessionId ||
        stored.activityEntryId != source.activityEntryId ||
        stored.dayId != source.dayId ||
        stored.planDate != source.planDate ||
        stored.capturedAt != source.createdAt ||
        stored.originHostId != source.originHostId ||
        stored.processingJobId !=
            DayProcessingOutboxRepository.transcriptionJobId(
              source.recordingSessionId,
            )) {
      return false;
    }
    final finalWavPath = manifest.finalWavPath;
    if (finalWavPath == null) return true;
    final journalPath = path.normalize(
      path.join(
        assetRoot.path,
        audio.data.audioDirectory.replaceFirst(RegExp('^/+'), ''),
        audio.data.audioFile,
      ),
    );
    return journalPath == path.normalize(finalWavPath);
  }

  /// Reuses the destination durably recorded before an interrupted
  /// finalization. Allocating another path would make an otherwise valid
  /// `finalizing` or `published` spool unrecoverable.
  File? _recoveryDestination(DurableAudioSpoolManifest manifest) {
    final recordedPath = manifest.finalWavPath;
    if (recordedPath != null) {
      final normalized = path.normalize(File(recordedPath).absolute.path);
      final root = path.normalize(assetRoot.absolute.path);
      if (!path.isWithin(root, normalized)) return null;
      return File(normalized);
    }
    final dayDirectory = _dayDirectory(manifest.context.createdAt);
    return File(
      path.join(
        assetRoot.path,
        'audio',
        dayDirectory,
        'recovered_${manifest.context.recordingSessionId}.wav',
      ),
    );
  }

  Future<JournalAudio?> _ownedOrExistingAudio(
    DurableAudioSpoolManifest manifest,
  ) async {
    final ownerId = manifest.journalAudioId;
    if (ownerId != null) {
      final owned = await journalDb.journalEntityById(ownerId);
      if (owned is JournalAudio && owned.meta.deletedAt == null) return owned;
    }
    return _findBySession(manifest.context.recordingSessionId);
  }

  Future<JournalAudio?> _findBySession(String recordingSessionId) async {
    return journalDb.journalAudioByRecordingSessionId(recordingSessionId);
  }

  String? _completedTranscript(JournalAudio audio) {
    final jobId = audio.data.dayContext?.processingJobId;
    if (jobId == null) return null;
    for (final transcript in (audio.data.transcripts ?? const []).reversed) {
      if (transcript.processingJobId == jobId &&
          transcript.transcript.trim().isNotEmpty) {
        return transcript.transcript.trim();
      }
    }
    return null;
  }

  String _dayDirectory(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
