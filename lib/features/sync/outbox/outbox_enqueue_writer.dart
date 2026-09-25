import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_attachment_policy.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/sync/vector_clock_logging.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path/path.dart' as p;

part 'outbox_enqueue_writer_simple.dart';
part 'outbox_enqueue_writer_agent.dart';

/// Per-message-type enqueue collaborator behind `OutboxService.enqueueMessage`:
/// message preparation (originating host, embedded links, covered vector
/// clocks) and persistence into the outbox table — one immutable row per
/// version, never merged (ADR 0086) — and sequence-log bookkeeping.
///
/// Deliberately free of any runner/timer/connectivity state — every
/// collaborator is injected, so the enqueue paths can be tested in isolation
/// from the send pipeline; the owning service schedules the send after every
/// enqueue.
class OutboxEnqueueWriter {
  OutboxEnqueueWriter({
    required this._journalDb,
    required this._loggingService,
    required this._syncDatabase,
    required this._documentsDirectory,
    required this._saveJson,
    required this._safePayloadFullPath,
    required this._sequenceLogService,
  });

  final JournalDb _journalDb;
  final DomainLogger _loggingService;
  final SyncDatabase _syncDatabase;
  final Directory _documentsDirectory;
  final Future<void> Function(String path, String json) _saveJson;

  /// Resolves a payload-relative path to a full path under the documents
  /// directory, returning null when the path would escape it. Shared with the
  /// owning service, which keeps its own copy for the public
  /// notification-enqueue entry point.
  final String? Function(String relativePath) _safePayloadFullPath;

  final SyncSequenceLogService? _sequenceLogService;

  void _logEnqueueSample(
    String message, {
    required String sampleKey,
    String subDomain = 'enqueueMessage',
  }) {
    _loggingService.logSampled(
      LogDomain.sync,
      message,
      sampleKey: 'outbox.$sampleKey',
      subDomain: subDomain,
    );
  }

  // ---------------------------------------------------------------------------
  // Message preparation
  // ---------------------------------------------------------------------------

  /// Prepares a SyncJournalEntity by adding originatingHostId, attaching entry
  /// links, and merging covered vector clocks.
  Future<SyncJournalEntity> prepareJournalEntity(
    SyncJournalEntity msg,
    String? host,
  ) async {
    var journalMsg = msg;

    // Add originating host ID (this device) for sequence tracking
    if (journalMsg.originatingHostId == null && host != null) {
      journalMsg = journalMsg.copyWith(originatingHostId: host);
    }

    // Attach entry links if available
    try {
      final links = await _journalDb
          .linksForEntryIdsBidirectionalIncludingRemoved({
            journalMsg.id,
          });
      if (links.isNotEmpty) {
        final fromCount = links
            .where((link) => link.fromId == journalMsg.id)
            .length;
        final toCount = links
            .where((link) => link.toId == journalMsg.id)
            .length;
        // Cap embedded links to prevent oversized envelopes. Remaining
        // links still sync independently as SyncEntryLink messages.
        final capped = links.length > SyncTuning.maxEmbeddedEntryLinks
            ? links.sublist(links.length - SyncTuning.maxEmbeddedEntryLinks)
            : links;
        _logEnqueueSample(
          'enqueueMessage.attachedLinks id=${journalMsg.id} '
          'count=${links.length} embedded=${capped.length} '
          'from=$fromCount to=$toCount',
          sampleKey: 'attachLinks.present',
          subDomain: 'enqueueMessage.attachLinks',
        );
        journalMsg = journalMsg.copyWith(entryLinks: capped);
      } else {
        _logEnqueueSample(
          'enqueueMessage.noLinks id=${journalMsg.id}',
          sampleKey: 'attachLinks.none',
          subDomain: 'enqueueMessage.attachLinks',
        );
      }
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'enqueueMessage.fetchLinks',
      );
      // Continue with original message without links on error
    }

    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?journalMsg.coveredVectorClocks,
      journalMsg.vectorClock,
    ]);
    if (coveredClocks != journalMsg.coveredVectorClocks) {
      journalMsg = journalMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncJournalEntity',
        entryId: journalMsg.id,
        jsonPath: journalMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: journalMsg.vectorClock,
        coveredVectorClocks: coveredClocks,
      );
    }

    return journalMsg;
  }

  /// Prepares a SyncEntryLink by adding originatingHostId and merging covered
  /// vector clocks.
  Future<SyncEntryLink> prepareEntryLink(
    SyncEntryLink msg,
    String? host,
  ) async {
    var linkMsg = msg;
    if (linkMsg.originatingHostId == null && host != null) {
      linkMsg = linkMsg.copyWith(originatingHostId: host);
    }
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?linkMsg.coveredVectorClocks,
      linkMsg.entryLink.vectorClock,
    ]);
    if (coveredClocks != linkMsg.coveredVectorClocks) {
      linkMsg = linkMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncEntryLink',
        entryId: linkMsg.entryLink.id,
        reason: 'ensure_current_clock_covered',
        assigned: linkMsg.entryLink.vectorClock,
        coveredVectorClocks: coveredClocks,
      );
    }
    return linkMsg;
  }

  /// Prepares a SyncAgentEntity by adding originatingHostId and merging covered
  /// vector clocks.
  SyncAgentEntity prepareAgentEntity(SyncAgentEntity msg, String? host) {
    var agentMsg = msg;
    if (agentMsg.originatingHostId == null && host != null) {
      agentMsg = agentMsg.copyWith(originatingHostId: host);
    }
    final vc = agentMsg.agentEntity?.vectorClock;
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?agentMsg.coveredVectorClocks,
      vc,
    ]);
    if (coveredClocks != agentMsg.coveredVectorClocks) {
      agentMsg = agentMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncAgentEntity',
        entryId: agentMsg.agentEntity?.id,
        jsonPath: agentMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: vc,
        coveredVectorClocks: coveredClocks,
      );
    }
    return agentMsg;
  }

  /// Prepares a SyncAgentLink by adding originatingHostId and merging covered
  /// vector clocks.
  SyncAgentLink prepareAgentLink(SyncAgentLink msg, String? host) {
    var linkMsg = msg;
    if (linkMsg.originatingHostId == null && host != null) {
      linkMsg = linkMsg.copyWith(originatingHostId: host);
    }
    final vc = linkMsg.agentLink?.vectorClock;
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?linkMsg.coveredVectorClocks,
      vc,
    ]);
    if (coveredClocks != linkMsg.coveredVectorClocks) {
      linkMsg = linkMsg.copyWith(coveredVectorClocks: coveredClocks);
      logVectorClockAssignment(
        _loggingService,
        subDomain: 'prepare.ensureCovered',
        action: 'assign',
        type: 'SyncAgentLink',
        entryId: linkMsg.agentLink?.id,
        jsonPath: linkMsg.jsonPath,
        reason: 'ensure_current_clock_covered',
        assigned: vc,
        coveredVectorClocks: coveredClocks,
      );
    }
    return linkMsg;
  }

  /// Prepares a SyncConsumptionEvent by adding originatingHostId and merging
  /// covered vector clocks. Mirrors [prepareEntryLink] (inline payload).
  SyncConsumptionEvent prepareConsumptionEvent(
    SyncConsumptionEvent msg,
    String? host,
  ) {
    var eventMsg = msg;
    if (eventMsg.originatingHostId == null && host != null) {
      eventMsg = eventMsg.copyWith(originatingHostId: host);
    }
    final coveredClocks = VectorClock.mergeUniqueClocks([
      ...?eventMsg.coveredVectorClocks,
      eventMsg.event.vectorClock,
    ]);
    if (coveredClocks != eventMsg.coveredVectorClocks) {
      eventMsg = eventMsg.copyWith(coveredVectorClocks: coveredClocks);
    }
    return eventMsg;
  }

  /// Routes message preparation based on type.
  Future<SyncMessage> prepareMessage(SyncMessage message, String? host) async {
    return switch (message) {
      final SyncJournalEntity msg => await prepareJournalEntity(msg, host),
      final SyncEntryLink msg => await prepareEntryLink(msg, host),
      final SyncAgentEntity msg => prepareAgentEntity(msg, host),
      final SyncAgentLink msg => prepareAgentLink(msg, host),
      final SyncConsumptionEvent msg => prepareConsumptionEvent(msg, host),
      final SyncConfigFlag msg =>
        msg.originatingHostId == null && host != null
            ? msg.copyWith(originatingHostId: host)
            : msg,
      _ => message,
    };
  }

  // ---------------------------------------------------------------------------
  // Per-type enqueue helpers
  // ---------------------------------------------------------------------------

  /// Appends a SyncJournalEntity row for this version. Rows are never merged:
  /// the processor collapses an entry's pending rows when it sends (ADR 0086).
  /// The stored row is read, including a deletion, which is a version too. A
  /// missing row fails the enqueue, so recovery cannot settle a counter
  /// against a payload that does not exist.
  Future<void> enqueueJournalEntity({
    required SyncJournalEntity msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    final journalEntity = await _journalDb.journalEntityByIdIncludingDeleted(
      msg.id,
    );
    if (journalEntity == null) {
      _loggingService.log(
        LogDomain.sync,
        'enqueueMessage.missingEntity id=${msg.id}',
        subDomain: 'enqueueMessage',
      );
      throw StateError('No stored journal entry ${msg.id} to enqueue');
    }

    final localCounter = journalEntity.meta.vectorClock?.vclock[host];

    // Resolved here, not just at send time: `filePath` on the row is what
    // keeps a media-bearing row out of the dequeue-time bundler, which ships
    // JSON manifests only, and what tells the collapse that one of the rows
    // it folds together still owes the peers its attachment.
    final sendAttachments = shouldSendJournalAttachments(
      status: msg.status,
      includeAttachments: msg.includeAttachments,
      resendAttachmentsFlag: await _journalDb.getConfigFlag(resendAttachments),
    );
    final attachment = sendAttachments ? _mediaFileFor(journalEntity) : null;
    final fileLength = await _attachmentLength(attachment);
    final subject = '$hostHash:$localCounter';

    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        filePath: Value(
          (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null,
        ),
        subject: Value(subject),
        outboxEntryId: Value(msg.id),
        payloadSize: Value((commonFields.payloadSize.value ?? 0) + fileLength),
      ),
    );
    _logEnqueueSample(
      'enqueue type=SyncJournalEntity subject=$subject id=${msg.id} '
      'attachBytes=$fileLength embeddedLinks=${msg.entryLinks?.length ?? 0}',
      sampleKey: 'insert.SyncJournalEntity',
    );

    // Record in sequence log for backfill support (self-healing sync)
    if (_sequenceLogService != null && journalEntity.meta.vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntry(
          entryId: journalEntity.meta.id,
          vectorClock: journalEntity.meta.vectorClock!,
        );
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'recordSent',
        );
      }
    }
  }

  /// The on-disk media file [entity] references, or null for entity types that
  /// carry no media. Pure path resolution — it does not check existence and
  /// does not consult the attachment policy.
  File? _mediaFileFor(JournalEntity entity) => entity.maybeMap(
    journalAudio: (JournalAudio journalAudio) =>
        File(AudioUtils.getAudioPath(journalAudio, _documentsDirectory)),
    journalImage: (JournalImage journalImage) => File(
      getFullImagePath(
        journalImage,
        documentsDirectory: _documentsDirectory.path,
      ),
    ),
    orElse: () => null,
  );

  /// Byte length of [attachment], or 0 when it is null or unreadable. A zero
  /// length is the signal used throughout the enqueue paths for "no attachment
  /// on this row" — a missing blob must not block the JSON from syncing.
  Future<int> _attachmentLength(File? attachment) async {
    if (attachment == null) return 0;
    try {
      return await attachment.length();
    } catch (_) {
      return 0;
    }
  }

  /// Appends a SyncEntryLink row for this version of the link. Rows are never
  /// merged; the processor collapses a link's pending rows when it sends.
  Future<void> enqueueEntryLink({
    required SyncEntryLink msg,
    required OutboxCompanion commonFields,
    required String? host,
    required String? hostHash,
  }) async {
    final linkId = msg.entryLink.id;
    final localCounter = msg.entryLink.vectorClock?.vclock[host];
    final subject = localCounter == null
        ? '$hostHash:link'
        : '$hostHash:link:$localCounter';

    await _syncDatabase.addOutboxItem(
      commonFields.copyWith(
        subject: Value(subject),
        outboxEntryId: Value(linkId),
      ),
    );
    _logEnqueueSample(
      'enqueue type=SyncEntryLink subject=$subject '
      'from=${msg.entryLink.fromId} to=${msg.entryLink.toId}',
      sampleKey: 'insert.SyncEntryLink',
    );

    // Record in sequence log for backfill support (self-healing sync)
    if (_sequenceLogService != null && msg.entryLink.vectorClock != null) {
      try {
        await _sequenceLogService.recordSentEntryLink(
          linkId: linkId,
          vectorClock: msg.entryLink.vectorClock!,
        );
      } catch (e, st) {
        _loggingService.error(
          LogDomain.sync,
          e,
          stackTrace: st,
          subDomain: 'recordSent',
        );
      }
    }
  }
}
