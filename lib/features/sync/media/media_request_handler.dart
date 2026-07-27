import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';

/// Responder half of media self-healing: answers a peer's [SyncMediaRequest]
/// by re-sending the requested entries with their blobs attached.
///
/// The answer is an ordinary `SyncJournalEntity` carrying
/// `includeAttachments: true`, so the existing send path does all the work —
/// the attachment policy resolves the file, the outbox row is stamped with a
/// `filePath` (which keeps it out of the dequeue-time bundler, whose manifest
/// carries no attachments), and the sender uploads the blob alongside the
/// JSON. There is no media-specific upload path to keep in step.
///
/// Nothing is sent back when this device cannot help — a request is a
/// broadcast and any peer may answer it, so silence from a device that lacks
/// the file is the normal case rather than an error worth reporting.
class MediaRequestHandler {
  MediaRequestHandler({
    required JournalDb journalDb,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required Directory documentsDirectory,
    required DomainLogger loggingService,
    int? maxEntriesPerRequest,
  }) : _db = journalDb,
       _outbox = outboxService,
       _vectorClock = vectorClockService,
       _docs = documentsDirectory,
       _logging = loggingService,
       _maxEntries = maxEntriesPerRequest ?? SyncTuning.mediaRepairMaxBatchSize;

  final JournalDb _db;
  final OutboxService _outbox;
  final VectorClockService _vectorClock;
  final Directory _docs;
  final DomainLogger _logging;
  final int _maxEntries;

  /// Re-sends every entry in [request] whose blob this device actually holds.
  ///
  /// Skips the whole request when it originated here — the request is
  /// broadcast, so this device receives its own — and skips individual
  /// entries that are unknown locally, carry no media, or whose file is
  /// missing or empty on this device too. Answering for a file we do not have
  /// would upload nothing while telling the requester its repair completed.
  Future<void> handleMediaRequest(SyncMediaRequest request) async {
    final host = await _vectorClock.getHost();
    if (host != null && request.requesterId == host) {
      return; // our own broadcast coming back to us
    }

    // A malformed or hostile request cannot make this device do unbounded
    // work: only the first [_maxEntries] ids are considered.
    final entryIds = request.entryIds.take(_maxEntries).toList();
    if (entryIds.isEmpty) return;

    final entities = await _db.journalEntityMapForIds(entryIds.toSet());

    var sent = 0;
    for (final entryId in entryIds) {
      final entity = entities[entryId];
      if (entity == null) continue;

      final relativePath = _mediaRelativePath(entity);
      if (relativePath == null) continue; // entry carries no media

      if (!_hasLocalBlob(relativePath)) continue;

      await _outbox.enqueueMessage(
        SyncMessage.journalEntity(
          id: entity.meta.id,
          jsonPath: relativeEntityPath(entity),
          vectorClock: entity.meta.vectorClock,
          status: SyncEntryStatus.update,
          // The point of the whole exchange: the requester holds the entry
          // already and is missing only the blob.
          includeAttachments: true,
        ),
      );
      sent++;
    }

    _logging.log(
      LogDomain.sync,
      'mediaRequest.answered requested=${entryIds.length} sent=$sent '
      'requester=${request.requesterId}',
      subDomain: 'mediaRequest.answered',
    );
  }

  /// The entry's media path relative to the documents directory, or null for
  /// entry types that carry no media.
  String? _mediaRelativePath(JournalEntity entity) => switch (entity) {
    JournalImage() => getRelativeImagePath(entity),
    JournalAudio() => AudioUtils.getRelativeAudioPath(entity),
    _ => null,
  };

  /// True when this device holds a non-empty copy of the blob. An empty file
  /// is treated as absent: it is the signature of an interrupted download,
  /// and uploading zero bytes would answer the request without repairing it.
  bool _hasLocalBlob(String relativePath) {
    try {
      final file = File('${_docs.path}$relativePath');
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }
}
