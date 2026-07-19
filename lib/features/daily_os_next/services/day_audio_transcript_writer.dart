import 'dart:async';

import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// Idempotently commits one durable processing result to its JournalAudio.
class DayAudioTranscriptWriter {
  DayAudioTranscriptWriter({
    required this.journalDb,
    required this.persistenceLogic,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final JournalDb journalDb;
  final PersistenceLogic persistenceLogic;
  final DateTime Function() _now;
  Future<void> _tail = Future<void>.value();

  static const _manualReceiptPrefix = 'manual:';

  Future<bool> attach({
    required DayProcessingJob job,
    required String transcript,
  }) => _serialize(() async {
    final entity = await journalDb.journalEntityById(job.audioId);
    if (entity is! JournalAudio || entity.meta.deletedAt != null) return false;
    final context = entity.data.dayContext;
    if (context == null ||
        context.processingJobId != job.id ||
        context.activityEntryId != job.activityEntryId) {
      return false;
    }
    final existing = entity.data.transcripts ?? const <AudioTranscript>[];
    if (existing.any((item) => item.processingJobId == job.id)) return true;
    final hasReviewedText = existing.any(
      (item) => item.processingJobId?.startsWith(_manualReceiptPrefix) ?? false,
    );

    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return false;
    final updated = entity.copyWith(
      meta: await persistenceLogic.updateMetadata(entity.meta),
      data: entity.data.copyWith(
        transcripts: <AudioTranscript>[
          ...existing,
          AudioTranscript(
            created: _now(),
            library: 'daily-os-outbox',
            model: 'configured-audio-model',
            detectedLanguage: '-',
            transcript: trimmed,
            processingJobId: job.id,
          ),
        ],
      ),
      entryText: hasReviewedText
          ? entity.entryText
          : EntryText(plainText: trimmed, markdown: trimmed),
    );
    return await persistenceLogic.updateDbEntity(updated) == true;
  });

  /// Persists user-reviewed text against a saved recording without waiting for
  /// transcription. The stable receipt ID makes repeated edits replace the
  /// same manual fact, and later automatic retries cannot overwrite it.
  Future<bool> attachManual({
    required String audioId,
    required String transcript,
  }) => _serialize(() async {
    final entity = await journalDb.journalEntityById(audioId);
    if (entity is! JournalAudio || entity.meta.deletedAt != null) return false;
    final context = entity.data.dayContext;
    if (context == null) return false;
    final trimmed = transcript.trim();
    if (trimmed.isEmpty) return false;
    final receiptId = '$_manualReceiptPrefix${context.activityEntryId}';
    final existing = entity.data.transcripts ?? const <AudioTranscript>[];
    final updated = entity.copyWith(
      meta: await persistenceLogic.updateMetadata(entity.meta),
      data: entity.data.copyWith(
        transcripts: <AudioTranscript>[
          for (final item in existing)
            if (item.processingJobId != receiptId) item,
          AudioTranscript(
            created: _now(),
            library: 'daily-os-manual',
            model: 'user-reviewed',
            detectedLanguage: '-',
            transcript: trimmed,
            processingJobId: receiptId,
          ),
        ],
      ),
      entryText: EntryText(plainText: trimmed, markdown: trimmed),
    );
    return await persistenceLogic.updateDbEntity(updated) == true;
  });

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
}
