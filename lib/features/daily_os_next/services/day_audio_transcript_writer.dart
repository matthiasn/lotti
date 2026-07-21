import 'dart:async';

import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/logic/persistence_logic.dart';

/// Receipt prefix used by the retired manual-edit dialog. Synced entities may
/// still carry these facts; they mark user-authored text, not machine output.
const String manualTranscriptReceiptPrefix = 'manual:';

/// Returns the user-authored text of a day recording, or null when its
/// `entryText` is absent, empty, or identical to machine transcription output.
///
/// The inline journal editor saves reviewed wording straight into `entryText`,
/// so "user-authored" is derived rather than flagged: any non-empty text that
/// no machine transcript produced counts as reviewed. Legacy `manual:`
/// receipts recorded user edits and are therefore excluded from the machine
/// comparison set.
String? journalAudioReviewedText(JournalAudio entity) {
  final text = entity.entryText?.plainText.trim() ?? '';
  if (text.isEmpty) return null;
  final machineFacts = (entity.data.transcripts ?? const <AudioTranscript>[])
      .where(
        (item) =>
            !(item.processingJobId?.startsWith(manualTranscriptReceiptPrefix) ??
                false),
      );
  return machineFacts.any((item) => item.transcript.trim() == text)
      ? null
      : text;
}

/// True when the recording's `entryText` was authored or edited by the user
/// and must never be overwritten by machine transcription output.
bool journalAudioHasReviewedText(JournalAudio entity) =>
    journalAudioReviewedText(entity) != null;

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
    final hasReviewedText = journalAudioHasReviewedText(entity);

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
