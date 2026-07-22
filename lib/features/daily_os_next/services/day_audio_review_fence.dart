import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/services/day_audio_transcript_writer.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/services/db_notification.dart';

/// Satisfies pending transcription jobs with user-reviewed text.
///
/// The inline journal editor saves a day recording's `entryText` through the
/// generic journal persistence path, which knows nothing about the day
/// processing outbox. This fence closes that gap: whenever a journal audio
/// update is broadcast, every non-terminal transcription job whose recording
/// now carries user-authored text is terminalized via
/// [DayProcessingOutboxRepository.satisfyWithReviewedText], so pending
/// provider work can no longer overwrite the user's wording or spend
/// inference tokens unnecessarily.
class DayAudioReviewFence {
  DayAudioReviewFence({
    required this.updates,
    required this.outbox,
    required this.journalDb,
  });

  final Stream<Set<String>> updates;
  final DayProcessingOutboxRepository outbox;
  final JournalDb journalDb;

  StreamSubscription<Set<String>>? _subscription;
  Future<void> _tail = Future<void>.value();

  /// Subscribes to journal updates and runs one initial sweep so an edit made
  /// just before the previous shutdown still fences its job on next launch.
  void start() {
    if (_subscription != null) return;
    _subscription = updates.listen((affectedIds) {
      if (affectedIds.contains(audioNotification)) {
        // A failed sweep is retried by the next audio update; nothing else
        // can act on the error here.
        unawaited(checkNow().then((_) {}, onError: (Object _) {}));
      }
    });
    unawaited(checkNow().then((_) {}, onError: (Object _) {}));
  }

  /// One full sweep over the outbox. Sweeps are strictly serialized, so a
  /// notification that arrives mid-sweep is re-evaluated against the journal
  /// state it produced instead of being lost to a stale read.
  Future<void> checkNow() {
    final result = _tail.then((_) => _sweep());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _sweep() async {
    final jobs = await outbox.getAll();
    for (final job in jobs) {
      if (job.isTerminal) continue;
      final audioId = job.audioId;
      if (audioId == null) continue;
      final entity = await journalDb.journalEntityById(audioId);
      if (entity is! JournalAudio || entity.meta.deletedAt != null) continue;
      final context = entity.data.dayContext;
      if (context == null || context.processingJobId != job.id) continue;
      final reviewed = journalAudioReviewedText(entity);
      if (reviewed == null) continue;
      await outbox.satisfyWithReviewedText(job.id, reviewed);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
