import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/audio_transcript_timing.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';

/// Writes only a timing sidecar, with an optimistic source check inside the
/// journal transaction. A concurrent privacy edit, deletion or text change
/// must win over a slow transcription response.
class QueryAudioTimingWriter {
  const QueryAudioTimingWriter({
    required this.journal,
    required this.persistence,
  });

  final JournalDb journal;
  final PersistenceLogic persistence;

  Future<bool> save({
    required JournalAudio expected,
    required AudioTranscriptTiming timing,
    required bool Function() isCancelled,
  }) => journal.transaction(() async {
    final current = await journal.journalEntityById(expected.id);
    if (current is! JournalAudio ||
        current != expected ||
        current.meta.deletedAt != null ||
        isCancelled()) {
      return false;
    }
    final metadata = await persistence.updateMetadata(current.meta);
    if (isCancelled()) return false;
    return await persistence.updateDbEntity(
          current.copyWith(
            meta: metadata,
            data: current.data.copyWith(
              transcriptTimings: {
                ...current.data.transcriptTimings,
                timing.sourceFingerprint: timing,
              },
            ),
          ),
        ) ==
        true;
  });
}

final queryAudioTimingWriterProvider = Provider<QueryAudioTimingWriter>(
  (ref) => QueryAudioTimingWriter(
    journal: ref.watch(journalDbProvider),
    persistence: getIt<PersistenceLogic>(),
  ),
);
