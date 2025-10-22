// ignore_for_file: one_member_abstracts

import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
import 'package:lotti/features/sync/matrix/utils/atomic_write.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as path;

/// Abstraction for loading journal entities and related attachments when
/// processing sync messages.
abstract class SyncJournalEntityLoader {
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  });
}

/// Loads journal entities from the documents directory on disk.
class FileSyncJournalEntityLoader implements SyncJournalEntityLoader {
  const FileSyncJournalEntityLoader();

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final candidateFile = resolveJsonCandidateFile(jsonPath);
    final docPath = path.normalize(getDocumentsDirectory().path);
    final jsonRelative = path.relative(candidateFile.path, from: docPath);
    return readEntityFromJson(jsonRelative);
  }
}

/// Smart loader that ensures JSON presence/currency based on an incoming vector
/// clock. It uses the AttachmentIndex to fetch missing/stale JSON and writes
/// atomically before parsing.
class SmartJournalEntityLoader implements SyncJournalEntityLoader {
  SmartJournalEntityLoader({
    required AttachmentIndex attachmentIndex,
    required LoggingService loggingService,
    void Function()? onCachePurge,
  })  : _attachmentIndex = attachmentIndex,
        _logging = loggingService {
    if (onCachePurge != null) {
      _cachePurgeListeners.add(onCachePurge);
    }
  }

  final AttachmentIndex _attachmentIndex;
  final LoggingService _logging;
  final List<void Function()> _cachePurgeListeners = <void Function()>[];

  void addCachePurgeListener(void Function()? listener) {
    if (listener == null) return;
    _cachePurgeListeners.add(listener);
  }

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final targetFile = resolveJsonCandidateFile(jsonPath);
    // Build a canonical index key once and reuse it to avoid inconsistencies
    // across platforms (Windows vs. POSIX). The key always uses forward slashes
    // and has a single leading '/'. Any leading '/' or '\\' characters are trimmed.
    final indexKey = _buildIndexKey(jsonPath);
    // If we have an incoming vector clock, decide whether a fetch is needed.
    if (incomingVectorClock != null) {
      try {
        final local =
            await const FileSyncJournalEntityLoader().load(jsonPath: jsonPath);
        final localVc = local.meta.vectorClock;
        if (localVc != null) {
          final status = VectorClock.compare(localVc, incomingVectorClock);
          if (status == VclockStatus.a_gt_b || status == VclockStatus.equal) {
            return local; // local is current or newer; no fetch
          }
        }
      } on FileSystemException {
        // Expected when text arrives before the descriptor: treat as a local miss.
        // We fetch via AttachmentIndex below; log as an info event rather than exception.
        _logging.captureEvent(
          'smart.local.miss path=$jsonPath',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.localMiss',
        );
      } catch (e, st) {
        // Unexpected read failure – keep as exception for diagnostics.
        _logging.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.localRead',
          stackTrace: st,
        );
      }

      // Resolve descriptor via AttachmentIndex
      final eventForPath = _attachmentIndex.find(indexKey);
      if (eventForPath == null) {
        // Descriptor not yet available; let caller retry later.
        _logging.captureEvent(
          'smart.fetch.miss path=$jsonPath key=$indexKey',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        throw FileSystemException(
          'attachment descriptor not yet available',
          jsonPath,
        );
      }
      try {
        await _downloadAndPersistDescriptor(
          descriptorEvent: eventForPath,
          incomingVectorClock: incomingVectorClock,
          jsonPath: jsonPath,
          targetFile: targetFile,
        );
      } catch (e, st) {
        _logging.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetchJson',
          stackTrace: st,
        );
        rethrow;
      }
    } else {
      // No incoming vector clock: fetch if file is missing/empty, else read.
      var needsFetch = false;
      try {
        if (!targetFile.existsSync()) {
          needsFetch = true;
        } else {
          final len = targetFile.lengthSync();
          needsFetch = len == 0;
        }
      } catch (_) {
        needsFetch = true;
      }
      if (needsFetch) {
        final eventForPath = _attachmentIndex.find(indexKey);
        if (eventForPath == null) {
          _logging.captureEvent(
            'smart.fetch.miss(noVc) path=$jsonPath key=$indexKey',
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetch',
          );
          throw FileSystemException(
            'attachment descriptor not yet available',
            jsonPath,
          );
        }
        try {
          final matrixFile = await eventForPath.downloadAndDecryptAttachment();
          final bytes = matrixFile.bytes;
          if (bytes.isEmpty) {
            throw const FileSystemException('empty attachment bytes');
          }
          final jsonString = utf8.decode(bytes);
          await saveJson(targetFile.path, jsonString);
          _logging.captureEvent(
            'smart.json.written(noVc) path=$jsonPath bytes=${bytes.length}',
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetch',
          );
        } catch (e, st) {
          _logging.captureException(
            e,
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchJson.noVc',
            stackTrace: st,
          );
          rethrow;
        }
      }
    }

    // Read and return the entity from disk (either pre-existing or freshly written).
    final entity =
        await const FileSyncJournalEntityLoader().load(jsonPath: jsonPath);

    // Ensure referenced media exists only when mentioned by JSON, and only if missing.
    await _ensureMediaOnMissing(entity);
    return entity;
  }

  Future<void> _downloadAndPersistDescriptor({
    required Event descriptorEvent,
    required VectorClock incomingVectorClock,
    required String jsonPath,
    required File targetFile,
  }) async {
    String? jsonToWrite;
    var bytesLength = 0;

    for (var attempt = 0; attempt < 2; attempt++) {
      final matrixFile = await descriptorEvent.downloadAndDecryptAttachment();
      final bytes = matrixFile.bytes;
      if (bytes.isEmpty) {
        throw const FileSystemException('empty attachment bytes');
      }
      final candidateJson = utf8.decode(bytes);
      final decoded = json.decode(candidateJson) as Map<String, dynamic>;
      final candidate = JournalEntity.fromJson(decoded);
      final candidateVc = candidate.meta.vectorClock;
      if (candidateVc != null) {
        final status = VectorClock.compare(candidateVc, incomingVectorClock);
        if (status == VclockStatus.b_gt_a) {
          if (attempt == 0) {
            _logging.captureEvent(
              'smart.fetch.stale_vc path=$jsonPath expected=$incomingVectorClock got=$candidateVc',
              domain: 'MATRIX_SERVICE',
              subDomain: 'SmartLoader.fetch',
            );
            final purged =
                await _maybePurgeCachedDescriptor(descriptorEvent, jsonPath);
            if (purged) {
              for (final listener in List<void Function()>.from(
                _cachePurgeListeners,
              )) {
                listener();
              }
            }
            _logging.captureEvent(
              'smart.fetch.stale_vc.refresh path=$jsonPath',
              domain: 'MATRIX_SERVICE',
              subDomain: 'SmartLoader.fetch',
            );
            continue;
          }
          _logging.captureEvent(
            'smart.fetch.stale_vc.pending path=$jsonPath expected=$incomingVectorClock got=$candidateVc',
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetch',
          );
          throw const FileSystemException(
              'stale attachment json after refresh');
        }
      } else {
        _logging.captureEvent(
          'smart.fetch.missing_vc path=$jsonPath expected=$incomingVectorClock',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        throw const FileSystemException('missing attachment vector clock');
      }
      jsonToWrite = candidateJson;
      bytesLength = bytes.length;
      break;
    }

    if (jsonToWrite == null) {
      throw const FileSystemException('stale attachment json');
    }

    await saveJson(targetFile.path, jsonToWrite);
    _logging.captureEvent(
      'smart.json.written path=$jsonPath bytes=$bytesLength',
      domain: 'MATRIX_SERVICE',
      subDomain: 'SmartLoader.fetch',
    );
  }

  Future<bool> _maybePurgeCachedDescriptor(
    Event event,
    String jsonPath,
  ) async {
    try {
      final uri = event.attachmentOrThumbnailMxcUrl();
      if (uri == null) {
        _logging.captureEvent(
          'smart.fetch.stale_vc.purge.skipped path=$jsonPath reason=no_mxc',
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        );
        return false;
      }
      await event.room.client.database.deleteFile(uri);
      _logging.captureEvent(
        'smart.fetch.stale_vc.purge path=$jsonPath mxc=$uri',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetch',
      );
      return true;
    } catch (e, st) {
      _logging.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.purge',
        stackTrace: st,
      );
      return false;
    }
  }

  // Construct a canonical index key for AttachmentIndex lookups.
  // - Normalizes separators using POSIX rules so keys always use '/'
  // - Trims any leading '/' or '\\' characters
  // - Returns the path with a single leading '/'
  String _buildIndexKey(String rawPath) {
    // Normalize with POSIX semantics and coerce backslashes to forward slashes.
    final normalizedPosix =
        path.posix.normalize(rawPath.replaceAll(r'\\', '/'));
    final trimmed = normalizedPosix.replaceFirst(RegExp(r'^[\\/]+'), '');
    return '/$trimmed';
  }

  Future<void> _ensureMediaOnMissing(JournalEntity e) async {
    switch (e) {
      case JournalImage():
        await _ensureMediaFile(getRelativeImagePath(e), mediaType: 'image');
      case JournalAudio():
        await _ensureMediaFile(
          AudioUtils.getRelativeAudioPath(e),
          mediaType: 'audio',
        );
      default:
        return; // No media to ensure
    }
  }

  Future<void> _ensureMediaFile(String relativePath,
      {String? mediaType}) async {
    final docDir = getDocumentsDirectory();
    final rp = relativePath;
    // Trim any leading '/' or '\\' to avoid accidental absolute paths on Windows.
    final rpRel = rp.replaceFirst(RegExp(r'^[\\/]+'), '');
    final fp = path.normalize(path.join(docDir.path, rpRel));
    final f = File(fp);
    try {
      if (f.existsSync()) {
        final len = f.lengthSync();
        if (len > 0) return; // present
      }
    } catch (e, st) {
      _logging.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.pathCheck',
        stackTrace: st,
      );
    }

    final descriptorKey = _buildIndexKey(rp);
    final ev = _attachmentIndex.find(descriptorKey);
    if (ev == null) {
      _logging.captureEvent(
        'smart.media.miss path=$rp key=$descriptorKey',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetchMedia',
      );
      throw FileSystemException('attachment descriptor not yet available', rp);
    }
    try {
      final file = await ev.downloadAndDecryptAttachment();
      final bytes = file.bytes;
      if (bytes.isEmpty) {
        throw const FileSystemException('empty attachment bytes');
      }
      await atomicWriteBytes(
        bytes: bytes,
        filePath: fp,
        logging: _logging,
        subDomain: 'SmartLoader.writeMedia',
      );
    } catch (e, st) {
      _logging.captureException(
        e,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SmartLoader.fetchMedia',
        stackTrace: st,
      );
      rethrow;
    }
  }
}

/// Decodes timeline events from Matrix and persists them locally.
class SyncEventProcessor {
  SyncEventProcessor({
    required LoggingService loggingService,
    required UpdateNotifications updateNotifications,
    required AiConfigRepository aiConfigRepository,
    SyncJournalEntityLoader? journalEntityLoader,
  })  : _loggingService = loggingService,
        _updateNotifications = updateNotifications,
        _aiConfigRepository = aiConfigRepository,
        _journalEntityLoader =
            journalEntityLoader ?? const FileSyncJournalEntityLoader();

  final LoggingService _loggingService;
  final UpdateNotifications _updateNotifications;
  final AiConfigRepository _aiConfigRepository;
  final SyncJournalEntityLoader _journalEntityLoader;
  void Function(SyncApplyDiagnostics diag)? applyObserver;
  void Function()? _cachePurgeListener;

  void Function()? get cachePurgeListener => _cachePurgeListener;

  set cachePurgeListener(void Function()? listener) {
    _cachePurgeListener = listener;
    final loader = _journalEntityLoader;
    if (loader is SmartJournalEntityLoader) {
      loader.addCachePurgeListener(listener);
    }
  }

  Future<void> process({
    required Event event,
    required JournalDb journalDb,
  }) async {
    try {
      final raw = event.text;
      final decoded = utf8.decode(base64.decode(raw));
      final messageJson = json.decode(decoded) as Map<String, dynamic>;
      final syncMessage = SyncMessage.fromJson(messageJson);

      _loggingService.captureEvent(
        'processing ${event.originServerTs} ${event.eventId}',
        domain: 'MATRIX_SERVICE',
        subDomain: 'SyncEventProcessor',
      );

      final diag = await _handleMessage(
        event: event,
        syncMessage: syncMessage,
        journalDb: journalDb,
        loader: _journalEntityLoader,
      );
      if (diag != null) {
        applyObserver?.call(diag);
      }
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SERVICE',
        subDomain: 'SyncEventProcessor',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<SyncApplyDiagnostics?> _handleMessage({
    required Event event,
    required SyncMessage syncMessage,
    required JournalDb journalDb,
    required SyncJournalEntityLoader loader,
  }) async {
    switch (syncMessage) {
      case SyncJournalEntity(jsonPath: final jsonPath):
        try {
          final journalEntity = await loader.load(
            jsonPath: jsonPath,
            incomingVectorClock: syncMessage.vectorClock,
          );
          var predictedStatus = VclockStatus.b_gt_a;
          if (applyObserver != null) {
            try {
              final existing =
                  await journalDb.journalEntityById(journalEntity.meta.id);
              final vcA = existing?.meta.vectorClock;
              final vcB0 = journalEntity.meta.vectorClock;
              if (vcA != null && vcB0 != null) {
                predictedStatus = VectorClock.compare(vcA, vcB0);
              }
            } catch (e, st) {
              _loggingService.captureException(
                e,
                domain: 'MATRIX_SERVICE',
                subDomain: 'apply.predictVectorClock',
                stackTrace: st,
              );
              predictedStatus = VclockStatus.b_gt_a;
            }
          }
          final vcB = journalEntity.meta.vectorClock;
          final updateResult =
              await journalDb.updateJournalEntity(journalEntity);
          final rows = updateResult.rowsWritten ?? 0;
          final diag = SyncApplyDiagnostics(
            eventId: event.eventId,
            payloadType: 'journalEntity',
            entityId: journalEntity.meta.id,
            vectorClock: vcB?.toJson(),
            conflictStatus: predictedStatus.toString(),
            applied: updateResult.applied,
            skipReason: updateResult.skipReason,
          );
          _loggingService.captureEvent(
            'apply journalEntity eventId=${event.eventId} id=${journalEntity.meta.id} rowsWritten=$rows applied=${updateResult.applied} skip=${updateResult.skipReason?.label ?? 'none'} status=${diag.conflictStatus}',
            domain: 'MATRIX_SERVICE',
            subDomain: 'apply',
          );
          _updateNotifications.notify(
            journalEntity.affectedIds,
            fromSync: true,
          );
          return diag;
        } on FileSystemException catch (error, stackTrace) {
          _loggingService.captureException(
            error,
            domain: 'MATRIX_SERVICE',
            subDomain: 'SyncEventProcessor.missingAttachment',
            stackTrace: stackTrace,
          );
          return null;
        }
      case SyncEntryLink(entryLink: final entryLink):
        final rows = await journalDb.upsertEntryLink(entryLink);
        try {
          if (rows > 0) {
            _loggingService.captureEvent(
              'apply entryLink from=${entryLink.fromId} to=${entryLink.toId} rows=$rows',
              domain: 'MATRIX_SERVICE',
              subDomain: 'apply.entryLink',
            );
          }
        } catch (_) {
          // best-effort logging only
        }
        // Surface DB-apply diagnostics to the pipeline when available.
        if (applyObserver != null) {
          try {
            final diag = SyncApplyDiagnostics(
              eventId: event.eventId,
              payloadType: 'entryLink',
              entityId: '${entryLink.fromId}->${entryLink.toId}',
              vectorClock: null,
              conflictStatus: rows == 0 ? 'entryLink.noop' : 'applied',
              applied: rows > 0,
              skipReason:
                  rows > 0 ? null : JournalUpdateSkipReason.olderOrEqual,
            );
            applyObserver!.call(diag);
          } catch (_) {
            // best-effort only
          }
        }
        _updateNotifications.notify(
          {entryLink.fromId, entryLink.toId},
          fromSync: true,
        );
        return null;
      case SyncEntityDefinition(entityDefinition: final entityDefinition):
        await journalDb.upsertEntityDefinition(entityDefinition);
        return null;
      case SyncTagEntity(tagEntity: final tagEntity):
        await journalDb.upsertTagEntity(tagEntity);
        return null;
      case SyncAiConfig(aiConfig: final aiConfig):
        await _aiConfigRepository.saveConfig(
          aiConfig,
          fromSync: true,
        );
        return null;
      case SyncAiConfigDelete(id: final id):
        await _aiConfigRepository.deleteConfig(
          id,
          fromSync: true,
        );
        return null;
    }
  }
}

class SyncApplyDiagnostics {
  SyncApplyDiagnostics({
    required this.eventId,
    required this.payloadType,
    required this.entityId,
    required this.vectorClock,
    required this.conflictStatus,
    required this.applied,
    this.skipReason,
  });

  final String eventId;
  final String payloadType;
  final String entityId;
  final Object? vectorClock;
  final String conflictStatus;
  final bool applied;
  final JournalUpdateSkipReason? skipReason;
}
