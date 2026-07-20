import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';

/// Rebuilds missing device-local processing intents from synced/persisted
/// JournalAudio provenance after a crash or receipt arriving from another
/// device.
class DayProcessingOutboxRepair {
  DayProcessingOutboxRepair({
    required this.repository,
    required this.journalDb,
    required this.assetRoot,
    this.currentHostId,
  });

  final DayProcessingOutboxRepository repository;
  final JournalDb journalDb;
  final Directory assetRoot;
  final String? currentHostId;

  Future<int> repair({int pageSize = 64}) async {
    var offset = 0;
    var repaired = 0;
    while (true) {
      final page = await journalDb.getJournalEntities(
        types: const <String>['JournalAudio'],
        starredStatuses: const <bool>[true, false],
        privateStatuses: const <bool>[true, false],
        flaggedStatuses: const <int>[1, 0],
        ids: null,
        limit: pageSize,
        offset: offset,
      );
      for (final audio in page.whereType<JournalAudio>()) {
        final context = audio.data.dayContext;
        if (context == null) continue;
        if (context.originHostId != null &&
            currentHostId != null &&
            context.originHostId != currentHostId) {
          continue;
        }
        final receipt = audio.data.transcripts
            ?.where((item) => item.processingJobId == context.processingJobId)
            .firstOrNull;
        final restored = await repository.restoreTranscriptionIntent(
          dayId: context.dayId,
          activityEntryId: context.activityEntryId,
          recordingSessionId: context.recordingSessionId,
          audioId: audio.meta.id,
          audioPath:
              '${assetRoot.path}${audio.data.audioDirectory}${audio.data.audioFile}',
          capturedAt: context.capturedAt,
          completedTranscript: receipt?.transcript,
        );
        if (restored) repaired += 1;
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return repaired;
  }
}
