// ignore_for_file: one_member_abstracts

import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
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
    final docDir = getDocumentsDirectory();
    final normalized = path.normalize(jsonPath);
    final relative = normalized.startsWith(path.separator)
        ? normalized.substring(1)
        : normalized;
    final candidate = path.normalize(path.join(docDir.path, relative));
    final docPath = path.normalize(docDir.path);
    if (!path.isWithin(docPath, candidate) && docPath != candidate) {
      throw FileSystemException(
        'jsonPath resolves outside documents directory',
        jsonPath,
      );
    }
    final jsonRelative = path.relative(candidate, from: docPath);
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
  })  : _attachmentIndex = attachmentIndex,
        _logging = loggingService;

  final AttachmentIndex _attachmentIndex;
  final LoggingService _logging;

  @override
  Future<JournalEntity> load({
    required String jsonPath,
    VectorClock? incomingVectorClock,
  }) async {
    final docDir = getDocumentsDirectory();
    final normalized = path.normalize(jsonPath);
    final relative = normalized.startsWith(path.separator)
        ? normalized.substring(1)
        : normalized;
    final candidate = path.normalize(path.join(docDir.path, relative));
    final docPath = path.normalize(docDir.path);
    if (!path.isWithin(docPath, candidate) && docPath != candidate) {
      throw FileSystemException(
        'jsonPath resolves outside documents directory',
        jsonPath,
      );
    }

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
      } catch (_) {
        // Missing or unreadable local JSON – proceed to fetch via index.
      }

      // Resolve descriptor via AttachmentIndex
      final indexKey =
          normalized.startsWith(path.separator) ? normalized : '/$relative';
      final eventForPath = _attachmentIndex.find(indexKey);
      if (eventForPath == null) {
        // Descriptor not yet available; let caller retry later.
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
        await saveJson(candidate, jsonString);
      } catch (e, st) {
        _logging.captureException(
          e,
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetchJson',
          stackTrace: st,
        );
        rethrow;
      }
    }

    // Read and return the entity from disk (either pre-existing or freshly written).
    final entity =
        await const FileSyncJournalEntityLoader().load(jsonPath: jsonPath);

    // Ensure referenced media exists only when mentioned by JSON, and only if missing.
    await _ensureMediaOnMissing(entity);
    return entity;
  }

  Future<void> _ensureMediaOnMissing(JournalEntity e) async {
    final docDir = getDocumentsDirectory();
    switch (e) {
      case JournalImage():
        final rp = getRelativeImagePath(e);
        final rpRel = rp.startsWith(path.separator) ? rp.substring(1) : rp;
        final fp = path.normalize(path.join(docDir.path, rpRel));
        final f = File(fp);
        try {
          if (f.existsSync()) {
            final len = f.lengthSync();
            if (len > 0) return; // present
          }
        } catch (_) {}
        final ev = _attachmentIndex.find(rp.startsWith('/') ? rp : '/$rp');
        if (ev == null) {
          // No descriptor yet; rely on retry path/upstream.
          throw FileSystemException(
              'attachment descriptor not yet available', rp);
        }
        try {
          final file = await ev.downloadAndDecryptAttachment();
          final bytes = file.bytes;
          if (bytes.isEmpty) {
            throw const FileSystemException('empty attachment bytes');
          }
          // Atomic write of media bytes
          final tmpPath =
              '$fp.tmp.${DateTime.now().microsecondsSinceEpoch}.$pid.media';
          final tmpFile = File(tmpPath);
          await tmpFile.parent.create(recursive: true);
          await tmpFile.writeAsBytes(bytes, flush: true);
          try {
            await tmpFile.rename(fp);
          } on FileSystemException catch (_) {
            try {
              // Best effort fallback
              if (File(fp).existsSync()) {
                final bak = '$fp.bak.${DateTime.now().microsecondsSinceEpoch}';
                try {
                  await File(fp).rename(bak);
                } catch (_) {}
              }
              await tmpFile.rename(fp);
            } catch (e, st) {
              _logging.captureException(
                e,
                domain: 'MATRIX_SERVICE',
                subDomain: 'SmartLoader.writeMedia',
                stackTrace: st,
              );
              try {
                await tmpFile.delete();
              } catch (_) {}
              rethrow;
            }
          }
        } catch (e, st) {
          _logging.captureException(
            e,
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchMedia',
            stackTrace: st,
          );
          rethrow;
        }
      case JournalAudio():
        final rp = AudioUtils.getRelativeAudioPath(e);
        final rpRel = rp.startsWith(path.separator) ? rp.substring(1) : rp;
        final fp = path.normalize(path.join(docDir.path, rpRel));
        final f = File(fp);
        try {
          if (f.existsSync()) {
            final len = f.lengthSync();
            if (len > 0) return; // present
          }
        } catch (_) {}
        final ev = _attachmentIndex.find(rp.startsWith('/') ? rp : '/$rp');
        if (ev == null) {
          throw FileSystemException(
              'attachment descriptor not yet available', rp);
        }
        try {
          final file = await ev.downloadAndDecryptAttachment();
          final bytes = file.bytes;
          if (bytes.isEmpty) {
            throw const FileSystemException('empty attachment bytes');
          }
          final tmpPath =
              '$fp.tmp.${DateTime.now().microsecondsSinceEpoch}.$pid.media';
          final tmpFile = File(tmpPath);
          await tmpFile.parent.create(recursive: true);
          await tmpFile.writeAsBytes(bytes, flush: true);
          try {
            await tmpFile.rename(fp);
          } on FileSystemException catch (_) {
            try {
              if (File(fp).existsSync()) {
                final bak = '$fp.bak.${DateTime.now().microsecondsSinceEpoch}';
                try {
                  await File(fp).rename(bak);
                } catch (_) {}
              }
              await tmpFile.rename(fp);
            } catch (e, st) {
              _logging.captureException(
                e,
                domain: 'MATRIX_SERVICE',
                subDomain: 'SmartLoader.writeMedia',
                stackTrace: st,
              );
              try {
                await tmpFile.delete();
              } catch (_) {}
              rethrow;
            }
          }
        } catch (e, st) {
          _logging.captureException(
            e,
            domain: 'MATRIX_SERVICE',
            subDomain: 'SmartLoader.fetchMedia',
            stackTrace: st,
          );
          rethrow;
        }
      default:
        return; // No media to ensure
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
          final rows = await journalDb.updateJournalEntity(journalEntity);
          final diag = SyncApplyDiagnostics(
            eventId: event.eventId,
            payloadType: 'journalEntity',
            entityId: journalEntity.meta.id,
            vectorClock: vcB?.toJson(),
            rowsAffected: rows,
            conflictStatus: predictedStatus.toString(),
          );
          _loggingService.captureEvent(
            'apply journalEntity eventId=${event.eventId} id=${journalEntity.meta.id} rows=$rows status=${diag.conflictStatus}',
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
          rethrow;
        }
      case SyncEntryLink(entryLink: final entryLink):
        await journalDb.upsertEntryLink(entryLink);
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
    required this.rowsAffected,
    required this.conflictStatus,
  });

  final String eventId;
  final String payloadType;
  final String entityId;
  final Object? vectorClock;
  final int rowsAffected;
  final String conflictStatus;
}
