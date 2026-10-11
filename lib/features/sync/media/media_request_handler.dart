import 'dart:async';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/media/entry_media.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:meta/meta.dart';

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
///
/// A request may name, per entry, the holder it expects to answer
/// (`SyncMediaRequest.holders`). Every other holder defers its answer by
/// [SyncTuning.mediaAnswerGrace] and drops it once an attachment for that
/// file arrives in the room at least as large as its own copy
/// (`observedAttachments`). So one device usually uploads the blob, an
/// offline holder cannot stall the request, and a short copy answered by an
/// old build is still replaced by a complete one (ADR 0137).
class MediaRequestHandler {
  MediaRequestHandler({
    required JournalDb journalDb,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required Directory documentsDirectory,
    required DomainLogger loggingService,
    Stream<ObservedAttachment>? observedAttachments,
    Duration? answerGrace,
    int? maxEntriesPerRequest,
  }) : _db = journalDb,
       _outbox = outboxService,
       _vectorClock = vectorClockService,
       _docs = documentsDirectory,
       _logging = loggingService,
       _grace = answerGrace ?? SyncTuning.mediaAnswerGrace,
       _maxEntries =
           maxEntriesPerRequest ?? SyncTuning.mediaRepairMaxBatchSize {
    _observed = observedAttachments?.listen(
      _attachmentObserved,
      onDone: _clearDeferred,
    );
  }

  final JournalDb _db;
  final OutboxService _outbox;
  final VectorClockService _vectorClock;
  final Directory _docs;
  final DomainLogger _logging;
  final Duration _grace;
  final int _maxEntries;
  StreamSubscription<ObservedAttachment>? _observed;

  /// Answers held back for another holder, by normalised media path.
  final Map<String, _DeferredAnswer> _deferred = {};

  /// Media paths whose answer is currently held back — test seam.
  Set<String> get debugDeferredPaths => Set.unmodifiable(_deferred.keys);

  /// Re-sends every entry in [request] whose blob this device actually holds,
  /// at once — or, for an entry the request addresses to another holder,
  /// after [SyncTuning.mediaAnswerGrace] unless that holder's answer arrives
  /// first.
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
    var deferred = 0;
    for (final entryId in entryIds) {
      final entity = entities[entryId];
      if (entity == null) continue;

      final media = entryMedia(entity, documentsDirectory: _docs);
      if (media == null) continue; // entry carries no media

      // An empty file is treated as absent: it is the signature of an
      // interrupted download, and uploading zero bytes would answer the
      // request without repairing it.
      final length = await mediaFileLength(media.file);
      if (length == 0) continue;

      final holder = request.holders?[entryId];
      if (holder != null && holder != host) {
        if (_defer(entryId, media.relativePath, length)) deferred++;
        continue;
      }

      await _answer(entity);
      sent++;
    }

    _logging.log(
      LogDomain.sync,
      'mediaRequest.answered requested=${entryIds.length} sent=$sent '
      'deferred=$deferred requester=${request.requesterId}',
      subDomain: 'mediaRequest.answered',
    );
  }

  /// Ends every grace at once and sends the answers still owed.
  ///
  /// Tests use this seam: the request path reads files, which fake time
  /// cannot drive, so the grace timer itself cannot be elapsed there.
  @visibleForTesting
  Future<void> expireGraceForTesting() async {
    final keys = _deferred.keys.toList();
    for (final key in keys) {
      _deferred[key]?.timer.cancel();
      await _answerDeferred(key);
    }
  }

  /// Stops listening and drops every held-back answer.
  Future<void> dispose() async {
    await _observed?.cancel();
    _observed = null;
    _clearDeferred();
  }

  Future<void> _answer(JournalEntity entity) => _outbox.enqueueMessage(
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

  /// Holds the answer for [entryId] back; false when one already waits.
  bool _defer(String entryId, String relativePath, int length) {
    final key = normalizeAttachmentIndexKey(relativePath);
    if (_deferred.containsKey(key)) return false;
    _deferred[key] = _DeferredAnswer(
      entryId: entryId,
      length: length,
      // _answerDeferred logs its own failures; nothing awaits a timer.
      timer: Timer(_grace, () => _answerDeferred(key).ignore()),
    );
    return true;
  }

  /// The grace ran out with no answer as large as this device's copy. A
  /// failure is logged: a timer has no caller to report it to.
  Future<void> _answerDeferred(String key) async {
    final pending = _deferred.remove(key);
    if (pending == null) return;
    try {
      final entity = (await _db.journalEntityMapForIds({
        pending.entryId,
      }))[pending.entryId];
      if (entity == null) return;
      final media = entryMedia(entity, documentsDirectory: _docs);
      if (media == null || await mediaFileLength(media.file) == 0) return;
      await _answer(entity);
      _logging.log(
        LogDomain.sync,
        'mediaRequest.answeredAfterGrace id=${pending.entryId}',
        subDomain: 'mediaRequest.answered',
      );
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'mediaRequest.answeredAfterGrace',
      );
    }
  }

  /// Another device's attachment for a held-back file: it answers the
  /// request when it is at least as large as this device's copy. A smaller
  /// or unsized one does not — this device's answer is still owed.
  void _attachmentObserved(ObservedAttachment observed) {
    final key = normalizeAttachmentIndexKey(observed.relativePath);
    final pending = _deferred[key];
    final size = observed.declaredSize;
    if (pending == null || size == null || size < pending.length) return;
    _deferred.remove(key)!.timer.cancel();
    _logging.log(
      LogDomain.sync,
      'mediaRequest.leftToHolder id=${pending.entryId} size=$size',
      subDomain: 'mediaRequest.answered',
    );
  }

  void _clearDeferred() {
    for (final pending in _deferred.values) {
      pending.timer.cancel();
    }
    _deferred.clear();
  }
}

class _DeferredAnswer {
  _DeferredAnswer({
    required this.entryId,
    required this.length,
    required this.timer,
  });

  final String entryId;

  /// This device's file length when the answer was held back.
  final int length;
  final Timer timer;
}
